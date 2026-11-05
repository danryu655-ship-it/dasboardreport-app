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
  }
}
