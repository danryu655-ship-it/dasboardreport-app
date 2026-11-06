// Hapus dua arah (live) + arsip Sheets — perubahan 2026-11-06.
// Menguji: builder tombstone, penjaga anti-false-delete, hapusan lokal
// berpenjaga di SQLite, antrean hapusan offline, dan merge arsip Sheets.
// Yang TIDAK diuji di sini (butuh Supabase live): round-trip push/pull
// tombstone lewat jaringan — diverifikasi manual (lihat SYNC_DELETE_RESULT.md).
import 'dart:io';

import 'package:dasboardreport/app_state.dart';
import 'package:dasboardreport/db.dart';
import 'package:dasboardreport/models.dart';
import 'package:dasboardreport/sync/sheets_backup.dart';
import 'package:dasboardreport/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late final Directory testDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // addLog memakai DateFormat(..., 'id_ID') — data locale harus
    // diinisialisasi dulu di lingkungan test.
    await initializeDateFormatting('id_ID');
    // File DB sendiri per file test: `flutter test` menjalankan file
    // secara paralel, dan DatabaseHelper memakai satu jalur tetap.
    testDbDir = await Directory.systemTemp.createTemp(
      'dasboardreport_sync_delete_test_',
    );
    DatabaseHelper.testDatabasePath = '${testDbDir.path}/test.db';
  });

  tearDownAll(() async {
    DatabaseHelper.testDatabasePath = null;
    try {
      await testDbDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseHelper.instance.database;
    for (final t in [
      'transactions',
      'bills',
      'debts',
      'profiles',
      'activity_logs',
      'bug_reports',
      'sync_queue',
    ]) {
      await db.delete(t);
    }
  });

  Future<AppState> freshState() async {
    final state = AppState();
    await state.init();
    await state.createProfile('Test');
    return state;
  }

  group('buildTombstone', () {
    test('transaksi/tagihan/utang menghasilkan tombstone lengkap', () {
      for (final table in ['transactions', 'bills', 'debts']) {
        final tomb = SyncService.buildTombstone(
          table: table,
          rowId: 1000,
          deletedAtMs: 2000,
          userId: 'user-1',
        );
        expect(tomb, isNotNull);
        expect(tomb!['table_name'], table);
        expect(tomb['row_id'], 1000);
        expect(tomb['user_id'], 'user-1');
        expect(tomb['deleted_at'], contains('1970-01-01'));
      }
    });

    test('profiles/bug_reports/wallets TIDAK memakai tombstone', () {
      for (final table in ['profiles', 'bug_reports', 'wallets']) {
        expect(
          SyncService.buildTombstone(
            table: table,
            rowId: 1,
            deletedAtMs: 2,
            userId: 'u',
          ),
          isNull,
        );
      }
    });
  });

  group('shouldApplyTombstone (penjaga anti-false-delete)', () {
    test('baris dibuat SEBELUM hapusan -> terapkan', () {
      expect(
        SyncService.shouldApplyTombstone(rowId: 1000, deletedAtMs: 2000),
        isTrue,
      );
    });

    test('baris dibuat SESUDAH hapusan -> jangan hapus', () {
      expect(
        SyncService.shouldApplyTombstone(rowId: 3000, deletedAtMs: 2000),
        isFalse,
      );
    });

    test('id SAMA dengan waktu hapusan (ambiguitas 1 ms) -> jangan hapus', () {
      expect(
        SyncService.shouldApplyTombstone(rowId: 2000, deletedAtMs: 2000),
        isFalse,
      );
    });
  });

  group('hapus lokal berpenjaga (SQLite)', () {
    test('transaksi lama terhapus, transaksi baru dipertahankan', () async {
      final db = DatabaseHelper.instance;
      final oldTrx = AppTransaction(
        id: 1000,
        profile: 'Test',
        jenis: 'pengeluaran',
        tanggal: '2026-11-01',
        kategori: 'Lainnya',
        metodePembayaran: 'Cash',
        keterangan: 'lama',
        nominal: 1000,
      );
      final newTrx = AppTransaction(
        id: 3000,
        profile: 'Test',
        jenis: 'pengeluaran',
        tanggal: '2026-11-01',
        kategori: 'Lainnya',
        metodePembayaran: 'Cash',
        keterangan: 'baru',
        nominal: 2000,
      );
      await db.insertTransaction(oldTrx);
      await db.insertTransaction(newTrx);
      await db.deleteTransactionIfCreatedBefore(1000, 2000);
      await db.deleteTransactionIfCreatedBefore(3000, 2000);
      final remaining = await db.getTransactions('Test');
      expect(remaining.map((t) => t.id), [3000]);
    });

    test('utang lama terhapus, utang baru dipertahankan', () async {
      final db = DatabaseHelper.instance;
      await db.insertDebt(
        Debt(
          id: 1000,
          profile: 'Test',
          creatorName: 'Test',
          partnerName: 'Lama',
          jenis: 'piutang',
          tipeTempo: 'tanpa_tempo',
          tanggal: '2026-11-01',
          nominal: 1000,
          keterangan: '',
          status: 'belum',
          syncCode: '',
        ),
      );
      await db.insertDebt(
        Debt(
          id: 3000,
          profile: 'Test',
          creatorName: 'Test',
          partnerName: 'Baru',
          jenis: 'piutang',
          tipeTempo: 'tanpa_tempo',
          tanggal: '2026-11-01',
          nominal: 2000,
          keterangan: '',
          status: 'belum',
          syncCode: '',
        ),
      );
      await db.deleteDebtIfCreatedBefore(1000, 2000);
      await db.deleteDebtIfCreatedBefore(3000, 2000);
      final remaining = await db.getDebts('Test');
      expect(remaining.map((d) => d.id), [3000]);
    });

    test('tagihan dengan id == deletedAt dipertahankan', () async {
      final db = DatabaseHelper.instance;
      await db.insertBill(
        Bill(
          id: 2000,
          profile: 'Test',
          nama: 'Tepat',
          nominal: 1000,
          tanggal: '2026-11-01',
          status: 'belum',
        ),
      );
      await db.deleteBillIfCreatedBefore(2000, 2000);
      final remaining = await db.getBills('Test');
      expect(remaining.length, 1);
    });
  });

  group('antrean hapusan offline', () {
    test('hapus di aplikasi -> entri delete masuk sync_queue', () async {
      final state = await freshState();
      await state.addTransaction(
        AppTransaction(
          id: 1000,
          profile: 'Test',
          jenis: 'pengeluaran',
          tanggal: '2026-11-01',
          kategori: 'Lainnya',
          metodePembayaran: 'Cash',
          keterangan: 'hapus saya',
          nominal: 5000,
        ),
      );
      await state.deleteTransaction(1000);
      final queue = await DatabaseHelper.instance.getSyncQueue();
      final deletes = queue
          .where((e) => e['operation'] == 'delete' && e['rowId'] == 1000)
          .toList();
      expect(deletes.length, 1);
      expect(deletes.first['tableName'], 'transactions');
    });

    test('deleteSyncEntries menguras antrean', () async {
      final db = DatabaseHelper.instance;
      await db.enqueueSync('transactions', 1, 'delete', '{"id":1}');
      await db.enqueueSync('transactions', 2, 'delete', '{"id":2}');
      var queue = await db.getSyncQueue();
      expect(queue.length, 2);
      await db.deleteSyncEntries([queue.first['id'] as int]);
      queue = await db.getSyncQueue();
      expect(queue.length, 1);
      expect(queue.first['rowId'], 2);
    });
  });

  group('mergeArchiveRows (arsip Sheets append-only)', () {
    test('baris lama yang tak ada di payload tetap dipertahankan', () {
      final merged = SheetsBackup.mergeArchiveRows(
        tab: 'Transaksi',
        existing: [
          {'id': 1, 'keterangan': 'lama'},
          {'id': 2, 'keterangan': 'tetap'},
        ],
        incoming: [
          {'id': 2, 'keterangan': 'tetap'},
        ],
      );
      expect(merged.length, 2);
      expect(merged[0]['keterangan'], 'lama');
    });

    test('baris yang berubah diperbarui di tempat, baris baru ditambah', () {
      final merged = SheetsBackup.mergeArchiveRows(
        tab: 'Transaksi',
        existing: [
          {'id': 1, 'keterangan': 'lama'},
          {'id': 2, 'keterangan': 'akan berubah'},
        ],
        incoming: [
          {'id': 2, 'keterangan': 'berubah'},
          {'id': 3, 'keterangan': 'baru'},
        ],
      );
      expect(merged.length, 3);
      expect(merged[1]['keterangan'], 'berubah');
      expect(merged[2]['keterangan'], 'baru');
    });

    test('hasil tidak pernah lebih pendek dari existing', () {
      final merged = SheetsBackup.mergeArchiveRows(
        tab: 'Transaksi',
        existing: [
          {'id': 1},
          {'id': 2},
          {'id': 3},
        ],
        incoming: [],
      );
      expect(merged.length, 3);
    });

    test('Profil dikunci kolom nama, bukan id', () {
      final merged = SheetsBackup.mergeArchiveRows(
        tab: 'Profil',
        existing: [
          {'id': 1, 'nama': 'Dan'},
        ],
        incoming: [
          {'id': 1, 'nama': 'Dan'},
          {'id': 1, 'nama': 'Baru'},
        ],
      );
      expect(merged.length, 2);
      expect(merged[1]['nama'], 'Baru');
    });
  });
}
