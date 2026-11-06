import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db.dart';
import '../models.dart';
import '../prefs.dart';
import 'supabase_config.dart';

/// Status sinkronisasi cloud (untuk ditampilkan di UI).
enum SyncStatus { disabled, idle, syncing, synced, error }

/// Sinkronisasi Supabase — offline-first.
///
/// Arsitektur:
/// - Data utama TETAP di SQLite lokal. Setiap mutasi lokal dicatat ke tabel
///   `sync_queue` (via [recordChange]) — tidak ada data yang hilang saat
///   offline.
/// - Bila Supabase terkonfigurasi (URL + anon key via --dart-define) dan ada
///   internet, antrean di-push (upsert/delete) ke tabel Supabase, lalu pull
///   baris yang berubah sejak sinkronisasi terakhir.
/// - Hapus DUA ARAH (sejak 2026-11-06): hapusan lokal di-push (baris server
///   dihapus + tombstone dicatat di tabel `sync_deletes`); pull membaca
///   tombstone dan menghapus baris lokal yang memang dihapus di Supabase.
///   Tombstone HANYA untuk tabel ber-id numerik ms epoch (transactions,
///   bills, debts) — profiles tidak memakai tombstone (tidak ada hapus
///   profil di UI, hanya rename), bug_reports tidak (id AUTOINCREMENT
///   bertabrakan antar perangkat; laporan bug hanya naik).
/// - Auth: anonymous (satu identitas per instalasi). RLS di Supabase
///   mengisolasi data per `auth.uid()`. Bila anonymous auth belum diaktifkan
///   di proyek Supabase, status menjadi error dan aplikasi tetap jalan lokal.
/// - Bila Supabase BELUM terkonfigurasi, semua method menjadi no-op dan
///   status [SyncStatus.disabled] — fitur inti tidak terhambat.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  SyncStatus _status = SyncStatus.disabled;
  SyncStatus get status => _status;

  String _lastError = '';
  String get lastError => _lastError;

  int _pendingCount = 0;
  int get pendingCount => _pendingCount;

  bool _initialized = false;
  bool _syncing = false;
  Timer? _debounce;

  /// Nama tabel Supabase — sama dengan tabel lokal (kecuali log & antrean).
  /// 'wallets' TIDAK ada di sini: web app tidak punya CRUD akun dompet,
  /// jadi aplikasi tidak menulis ke tabel wallets (lihat supabase-schema.sql).
  static const List<String> syncTables = [
    'profiles',
    'transactions',
    'bills',
    'debts',
    'bug_reports',
  ];

  /// Tabel yang memakai tombstone hapusan di `sync_deletes`.
  /// Syarat: id numerik = ms epoch pembuatan, sehingga pull bisa membedakan
  /// baris yang dibuat SEBELUM hapusan (harus ikut terhapus) dari baris
  /// yang dibuat SESUDAH hapusan (data baru, jangan hapus).
  static const List<String> tombstoneTables = [
    'transactions',
    'bills',
    'debts',
  ];

  /// Bangun baris tombstone dari satu entri antrean hapusan.
  /// Mengembalikan null bila tabel tidak memakai tombstone (profiles,
  /// bug_reports, wallets) — hapusan tabel itu tetap di-push ke server
  /// seperti biasa, hanya saja tidak meninggalkan jejak untuk pull.
  /// `deletedAtMs` = waktu hapusan dicatat lokal (createdAt antrean).
  static Map<String, dynamic>? buildTombstone({
    required String table,
    required int rowId,
    required int deletedAtMs,
    required String userId,
  }) {
    if (!tombstoneTables.contains(table)) return null;
    return {
      'table_name': table,
      'row_id': rowId,
      'row_key': '',
      'deleted_at':
          DateTime.fromMillisecondsSinceEpoch(deletedAtMs).toIso8601String(),
      'user_id': userId,
    };
  }

  /// Penjaga anti-false-delete untuk pull: terapkan tombstone hanya bila
  /// baris lokal dibuat SEBELUM hapusan (id = ms epoch pembuatan).
  /// Baris dengan id > deletedAt dibuat sesudah hapusan (data baru atau
  /// dibuat ulang) — jangan hapus. id == deletedAt (ambiguitas 1 ms)
  /// juga TIDAK dihapus: lebih aman mempertahankan baris.
  static bool shouldApplyTombstone({
    required int rowId,
    required int deletedAtMs,
  }) =>
      rowId < deletedAtMs;

  /// Inisialisasi Supabase bila terkonfigurasi. Aman dipanggil kapan saja;
  /// bila tidak terkonfigurasi, langsung menjadi disabled.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!CloudConfig.isSupabaseConfigured) {
      _setStatus(SyncStatus.disabled);
      return;
    }
    try {
      await Supabase.initialize(
        url: CloudConfig.supabaseUrl,
        // publishableKey = anon key (nama baru Supabase; nilainya sama).
        publishableKey: CloudConfig.supabaseAnonKey,
      );
      // Auth anonim: satu identitas stabil per instalasi (tanpa login email).
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }
      _setStatus(SyncStatus.idle);
      await _refreshPendingCount();
      unawaited(syncNow());
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  void _setStatus(SyncStatus s) {
    _status = s;
    notifyListeners();
  }

  Future<void> _refreshPendingCount() async {
    _pendingCount = await DatabaseHelper.instance.syncQueueCount();
    notifyListeners();
  }

  /// Catat perubahan lokal ke antrean sync (dipanggil AppState setiap
  /// mutasi). Selalu berhasil offline; lalu coba sync (debounce 2 detik).
  Future<void> recordChange(
    String table,
    int rowId,
    String operation,
    Map<String, dynamic> row,
  ) async {
    await DatabaseHelper.instance.enqueueSync(
      table,
      rowId,
      operation,
      jsonEncode(row),
    );
    await _refreshPendingCount();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      unawaited(syncNow());
    });
  }

  /// Dorong antrean lalu tarik perubahan server. No-op bila tidak
  /// terkonfigurasi / tidak ada sesi / sedang sync.
  Future<void> syncNow() async {
    if (!CloudConfig.isSupabaseConfigured || _syncing) return;
    if (!_initialized) await init();
    if (_status == SyncStatus.disabled || _status == SyncStatus.error) {
      return;
    }
    if (_userId == null) return;
    _syncing = true;
    _setStatus(SyncStatus.syncing);
    try {
      await _pushQueue();
      await _pullChanges();
      await PrefsHelper.setLastSyncAt(DateTime.now().millisecondsSinceEpoch);
      await _refreshPendingCount();
      _setStatus(SyncStatus.synced);
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushQueue() async {
    final entries = await DatabaseHelper.instance.getSyncQueue();
    if (entries.isEmpty) return;
    final doneIds = <int>[];
    for (final e in entries) {
      final table = e['tableName'] as String;
      final operation = e['operation'] as String;
      final rowId = e['rowId'] as int;
      final payload =
          jsonDecode(e['payload'] as String) as Map<String, dynamic>;
      if (!syncTables.contains(table)) {
        doneIds.add(e['id'] as int);
        continue;
      }
      final row = Map<String, dynamic>.from(payload)
        ..['user_id'] = _userId
        ..['updated_at'] = DateTime.now().toIso8601String();
      if (operation == 'delete') {
        if (table == 'profiles') {
          // Profil tidak punya id numerik: hapus berdasarkan nama.
          await _client
              .from(table)
              .delete()
              .eq('name', payload['name'] as String)
              .eq('user_id', _userId!);
        } else {
          await _client
              .from(table)
              .delete()
              .eq('id', rowId)
              .eq('user_id', _userId!);
        }
        // Jejak hapusan untuk pull perangkat lain (hapus dua arah).
        // Idempotent: upsert di (user_id, table_name, row_id, row_key) —
        // bila push diulang (mis. gagal di tengah jalan), tidak ada
        // tombstone ganda. Gagal di sini membuat entri antrean tetap ada
        // dan dicoba lagi pada sync berikutnya.
        final tombstone = buildTombstone(
          table: table,
          rowId: rowId,
          deletedAtMs: e['createdAt'] as int,
          userId: _userId!,
        );
        if (tombstone != null) {
          await _client.from('sync_deletes').upsert(
                tombstone,
                onConflict: 'user_id,table_name,row_id,row_key',
              );
        }
      } else {
        await _client.from(table).upsert(row);
      }
      doneIds.add(e['id'] as int);
    }
    await DatabaseHelper.instance.deleteSyncEntries(doneIds);
  }

  Future<void> _pullChanges() async {
    final lastSync = await PrefsHelper.getLastSyncAt();
    final since = lastSync == null
        ? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String()
        : DateTime.fromMillisecondsSinceEpoch(lastSync).toIso8601String();
    final db = DatabaseHelper.instance;
    for (final table in syncTables) {
      final rows = await _client
          .from(table)
          .select()
          .eq('user_id', _userId!)
          .gt('updated_at', since);
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map)
          ..remove('user_id')
          ..remove('updated_at');
        switch (table) {
          case 'profiles':
            await db.insertProfile(map['name'] as String);
          case 'transactions':
            await db.insertTransaction(AppTransaction.fromMap(map));
          case 'bills':
            await db.insertBill(Bill.fromMap(map));
          case 'debts':
            await db.insertDebt(Debt.fromMap(map));
          case 'bug_reports':
            // Laporan bug hanya naik (push); pull diabaikan agar tidak
            // menimpa laporan lokal dengan id AUTOINCREMENT yang berbeda.
            break;
        }
      }
    }
    // Hapusan dari perangkat lain: terapkan tombstone (hapus dua arah).
    await _pullDeletes(since);
  }

  /// Tarik tombstone hapusan sejak [since] (ISO-8601) dan hapus baris lokal
  /// yang memang dihapus di Supabase. TIDAK PERNAH menghapus tanpa bukti:
  /// hanya baris yang cocok dengan satu tombstone (tabel + id) DAN dibuat
  /// sebelum hapusan yang dihapus. Tombstone untuk tabel yang tidak memakai
  /// tombstone (profiles, bug_reports, wallets) diabaikan.
  Future<void> _pullDeletes(String since) async {
    final tombstones = await _client
        .from('sync_deletes')
        .select()
        .eq('user_id', _userId!)
        .gt('deleted_at', since);
    final db = DatabaseHelper.instance;
    for (final t in tombstones as List) {
      final map = Map<String, dynamic>.from(t as Map);
      final table = map['table_name'] as String? ?? '';
      if (!tombstoneTables.contains(table)) continue;
      final rowId = (map['row_id'] as num?)?.toInt();
      final deletedAt = map['deleted_at'] as String?;
      if (rowId == null || deletedAt == null) continue;
      final deletedAtMs =
          DateTime.parse(deletedAt).millisecondsSinceEpoch;
      if (!shouldApplyTombstone(rowId: rowId, deletedAtMs: deletedAtMs)) {
        continue;
      }
      switch (table) {
        case 'transactions':
          await db.deleteTransactionIfCreatedBefore(rowId, deletedAtMs);
        case 'bills':
          await db.deleteBillIfCreatedBefore(rowId, deletedAtMs);
        case 'debts':
          await db.deleteDebtIfCreatedBefore(rowId, deletedAtMs);
      }
    }
  }
}
