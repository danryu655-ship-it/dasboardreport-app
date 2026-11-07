// Filter Piutang di Wallet bersifat eksklusif — laporan user 2026-11-07
// (screenshot: chip Piutang aktif tapi daftar masih menampilkan belanja
// seperti "Beli Celana").
// Regresi ganda:
//  1. walletDebts(jenis:'piutang') dulu mengabaikan jenis -> ikut
//     menampilkan utang.
//  2. WalletScreen dulu memuat SEMUA transaksi saat filter Piutang aktif.
// Perilaku benar: chip Piutang hanya menampilkan rekap piutang (tanpa
// transaksi pemasukan/pengeluaran dan tanpa utang) + kartu rekap total
// piutang belum lunas.
//
// Catatan pola: di dalam testWidgets, semua I/O asli (SharedPreferences,
// sqflite) HARUS dibungkus tester.runAsync — kalau tidak, await di zona
// FakeAsync tidak pernah selesai (pola yang sama dipakai
// debt_series_delete_test.dart).
import 'dart:io';

import 'package:dasboardreport/app_state.dart';
import 'package:dasboardreport/db.dart';
import 'package:dasboardreport/models.dart';
import 'package:dasboardreport/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late final Directory testDbDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('id_ID');
    testDbDir = await Directory.systemTemp.createTemp(
      'dasboardreport_wallet_piutang_test_',
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

  Future<void> pumpWallet(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chip Piutang hanya menampilkan rekap piutang', (
    WidgetTester tester,
  ) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() async {
      await state.addTransaction(
        const AppTransaction(
          id: 1,
          profile: 'Test',
          jenis: 'pengeluaran',
          tanggal: '2026-10-18',
          kategori: 'Belanja',
          metodePembayaran: 'Transfer Bank',
          keterangan: 'Beli Celana',
          nominal: 450000,
        ),
      );
      await state.addTransaction(
        const AppTransaction(
          id: 2,
          profile: 'Test',
          jenis: 'pemasukan',
          tanggal: '2026-10-18',
          kategori: 'Gaji',
          keterangan: 'Gaji Oktober',
          nominal: 5000000,
        ),
      );
      await state.addDebt(
        const Debt(
          id: 10,
          profile: 'Test',
          creatorName: 'Test',
          partnerName: 'Budi',
          jenis: 'piutang',
          tanggal: '2026-10-18',
          nominal: 1000000,
          keterangan: '',
          status: 'belum',
        ),
      );
      await state.addDebt(
        const Debt(
          id: 11,
          profile: 'Test',
          creatorName: 'Test',
          partnerName: 'Tono',
          jenis: 'utang',
          tanggal: '2026-10-18',
          nominal: 500000,
          keterangan: '',
          status: 'belum',
        ),
      );
    });

    await pumpWallet(tester, state);

    // Mode Semua: semuanya tampil.
    expect(find.text('Beli Celana'), findsOneWidget);
    expect(find.text('Gaji Oktober'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Tono'), findsOneWidget);

    // Aktifkan filter Piutang.
    await tester.tap(find.text('Piutang'));
    await tester.pumpAndSettle();

    // Eksklusif: hanya piutang Budi + kartu rekapnya.
    expect(find.text('Beli Celana'), findsNothing);
    expect(find.text('Gaji Oktober'), findsNothing);
    expect(find.text('Tono'), findsNothing);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Total Piutang Belum Lunas'), findsOneWidget);
    expect(find.text('Rp 1.000.000'), findsOneWidget);
    expect(find.text('Catatan Belum Lunas'), findsOneWidget);
  });

  test('walletDebts benar-benar memfilter berdasarkan jenis', () async {
    final state = await freshState();
    await state.addDebt(
      const Debt(
        id: 20,
        profile: 'Test',
        creatorName: 'Test',
        partnerName: 'Budi',
        jenis: 'piutang',
        tanggal: '2026-10-18',
        nominal: 1000000,
        keterangan: '',
        status: 'belum',
      ),
    );
    await state.addDebt(
      const Debt(
        id: 21,
        profile: 'Test',
        creatorName: 'Test',
        partnerName: 'Tono',
        jenis: 'utang',
        tanggal: '2026-10-18',
        nominal: 500000,
        keterangan: '',
        status: 'belum',
      ),
    );
    final piutang = state.walletDebts(jenis: 'piutang');
    expect(piutang.map((d) => d.partnerName), ['Budi']);
    final utang = state.walletDebts(jenis: 'utang');
    expect(utang.map((d) => d.partnerName), ['Tono']);
  });
}
