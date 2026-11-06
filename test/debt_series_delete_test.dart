// Hapus satu seri sekaligus — keputusan user 2026-11-06.
// Satu seri = semua cicilan dengan identitas pinjaman yang sama
// (profil, pihak, jenis, tenor, nominal, keterangan). Identitas seri
// BUKAN syncCode: baik web maupun aplikasi selama ini memberi kode BARU
// di tiap cicilan, dan baris pertama dari form punya syncCode '' — jadi
// pengelompokan berdasarkan kode tidak pernah menyatukan satu seri.
// Regresi: hapus satu baris dari seri 12 cicilan -> 12 baris hilang +
// 12 entri delete terantre (satu tombstone per baris saat push);
// batal di dialog -> tidak ada yang terhapus; seri 1 baris -> hanya
// baris itu; cicilan berikutnya mewarisi kode seri (dan mengisi kode ke
// induk bila masih kosong).
import 'dart:io';

import 'package:dasboardreport/app_state.dart';
import 'package:dasboardreport/db.dart';
import 'package:dasboardreport/models.dart';
import 'package:dasboardreport/screens/debts_screen.dart';
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
    // File DB sendiri per file test: `flutter test` menjalankan file
    // secara paralel, dan DatabaseHelper memakai satu jalur tetap.
    testDbDir = await Directory.systemTemp.createTemp(
      'dasboardreport_debt_series_test_',
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

  Debt cicilan({
    required int id,
    required int ke,
    String status = 'belum',
    String syncCode = '',
    String partner = 'Piutang Test',
    String jenis = 'piutang',
    int? tenor = 12,
    int nominal = 5000000,
    String keterangan = '',
    String tanggal = '2026-11-10',
  }) => Debt(
    id: id,
    profile: 'Test',
    creatorName: 'Test',
    partnerName: partner,
    jenis: jenis,
    tipeTempo: 'cicilan',
    tenorBulan: tenor,
    cicilanKe: ke,
    tanggal: tanggal,
    nominal: nominal,
    keterangan: keterangan,
    status: status,
    syncCode: syncCode,
  );

  /// Seri 12 cicilan seperti data nyata: baris pertama dari form
  /// (syncCode ''), cicilan berikutnya masing-masing berkode baru —
  /// persis perilaku lama web + aplikasi sebelum perbaikan ini.
  Future<List<Debt>> seedSeries12(AppState state) async {
    final rows = <Debt>[];
    for (var i = 0; i < 12; i++) {
      final d = cicilan(
        id: 1000 + i,
        ke: i + 1,
        status: i == 0 ? 'sudah' : 'belum',
        syncCode: i == 0 ? '' : 'UTG-CODE${i.toString().padLeft(2, '0')}',
        tanggal: '2026-1${(i % 2)}-10',
      );
      rows.add(d);
      await state.addDebt(d);
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> debtDeleteQueue() async {
    final q = await DatabaseHelper.instance.getSyncQueue(limit: 500);
    return q
        .where((e) => e['tableName'] == 'debts' && e['operation'] == 'delete')
        .toList();
  }

  Future<void> pumpDebts(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: DebtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tunggu sampai teks hilang dari layar (pola drain yang sama dengan
  /// debt_delete_test.dart: jangan berhenti begitu state kosong, karena
  /// _loadProfileData + notifyListeners masih berjalan; pump 3 detik
  /// setelahnya agar timer debounce sync 2 detik selesai).
  Future<void> waitGone(
    WidgetTester tester,
    String text, {
    int maxRounds = 30,
  }) async {
    for (
      var i = 0;
      i < maxRounds && find.text(text).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  test('seriesOf mengelompokkan 12 cicilan berkode campur jadi 1 seri', () async {
    final state = await freshState();
    final rows = await seedSeries12(state);
    expect(state.debts.length, 12);
    // Dari baris lunas (kode '') maupun dari baris aktif (berkode):
    // serinya sama, 12 baris.
    expect(AppState.seriesOf(state.debts, rows.first).length, 12);
    expect(AppState.seriesOf(state.debts, rows.last).length, 12);
    expect(state.debtSeriesOf(rows[5]).length, 12);
  });

  test('tenor / pihak / jenis berbeda -> seri berbeda', () async {
    final state = await freshState();
    await seedSeries12(state);
    // Tenor 6 bulan, pihak/jenis/nominal sama -> seri lain.
    await state.addDebt(cicilan(id: 2000, ke: 1, tenor: 6));
    // Pihak lain, sisanya sama -> seri lain.
    await state.addDebt(cicilan(id: 2001, ke: 1, partner: 'Orang Lain'));
    // Jenis utang (bukan piutang), sisanya sama -> seri lain.
    await state.addDebt(cicilan(id: 2002, ke: 1, jenis: 'utang'));
    expect(state.debts.length, 15);
    expect(state.debtSeriesOf(state.debts.firstWhere((d) => d.id == 1000)).length, 12);
    expect(state.debtSeriesOf(state.debts.firstWhere((d) => d.id == 2000)).length, 1);
    expect(state.debtSeriesOf(state.debts.firstWhere((d) => d.id == 2001)).length, 1);
    expect(state.debtSeriesOf(state.debts.firstWhere((d) => d.id == 2002)).length, 1);
  });

  test('tanpa tempo -> seri satu baris', () async {
    final state = await freshState();
    await state.addDebt(
      Debt(
        id: 1000,
        profile: 'Test',
        creatorName: 'Test',
        partnerName: 'Piutang Test',
        jenis: 'piutang',
        tipeTempo: 'tanpa_tempo',
        tanggal: '2026-11-10',
        nominal: 5000000,
        keterangan: '',
        status: 'belum',
      ),
    );
    await state.addDebt(
      Debt(
        id: 1001,
        profile: 'Test',
        creatorName: 'Test',
        partnerName: 'Piutang Test',
        jenis: 'piutang',
        tipeTempo: 'tanpa_tempo',
        tanggal: '2026-11-11',
        nominal: 5000000,
        keterangan: '',
        status: 'belum',
      ),
    );
    expect(state.debtSeriesOf(state.debts.first).length, 1);
  });

  test('deleteDebtSeries 12 cicilan -> 12 hilang + 12 entri delete terantre', () async {
    final state = await freshState();
    await seedSeries12(state);
    await DatabaseHelper.instance.deleteSyncEntries(
      (await DatabaseHelper.instance.getSyncQueue(limit: 500))
          .map((e) => e['id'] as int)
          .toList(),
    );
    final removed = await state.deleteDebtSeries(1005);
    expect(removed, 12);
    expect(state.debts, isEmpty);
    final deletes = await debtDeleteQueue();
    expect(deletes.length, 12);
    // Satu entri per baris: 12 rowId berbeda, semua id seri.
    expect(deletes.map((e) => e['rowId'] as int).toSet().length, 12);
    expect(
      deletes.map((e) => e['rowId'] as int).toSet(),
      containsAll(List.generate(12, (i) => 1000 + i)),
    );
  });

  test('deleteDebtSeries seri 1 baris -> hanya baris itu', () async {
    final state = await freshState();
    await state.addDebt(cicilan(id: 1000, ke: 1));
    final removed = await state.deleteDebtSeries(1000);
    expect(removed, 1);
    expect(state.debts, isEmpty);
    expect((await debtDeleteQueue()).length, 1);
  });

  test('deleteDebtSeries id tidak ada -> 0, tidak ada yang terhapus', () async {
    final state = await freshState();
    await seedSeries12(state);
    final removed = await state.deleteDebtSeries(9999);
    expect(removed, 0);
    expect(state.debts.length, 12);
  });

  test('createNextInstallment mewarisi kode seri induk', () async {
    final state = await freshState();
    await state.addDebt(
      cicilan(id: 1000, ke: 1, syncCode: 'UTG-ABCDEF'),
    );
    await state.settleDebt(1000);
    await state.createNextInstallment(1000);
    expect(state.debts.length, 2);
    final child = state.debts.firstWhere((d) => d.cicilanKe == 2);
    expect(child.syncCode, 'UTG-ABCDEF');
    expect(child.status, 'belum');
  });

  test('createNextInstallment mengisi kode ke induk yang masih kosong', () async {
    final state = await freshState();
    await state.addDebt(cicilan(id: 1000, ke: 1, syncCode: ''));
    await state.settleDebt(1000);
    await state.createNextInstallment(1000);
    final parent = state.debts.firstWhere((d) => d.cicilanKe == 1);
    final child = state.debts.firstWhere((d) => d.cicilanKe == 2);
    expect(parent.syncCode, isNotEmpty);
    expect(child.syncCode, parent.syncCode);
    expect(parent.syncCode.startsWith('UTG-'), isTrue);
  });

  testWidgets('tile cicilan berlabel Hapus Seri; tanpa tempo berlabel Hapus', (
    tester,
  ) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() async {
      await state.addDebt(cicilan(id: 1000, ke: 1));
      await state.addDebt(
        Debt(
          id: 2000,
          profile: 'Test',
          creatorName: 'Test',
          partnerName: 'Piutang Test',
          jenis: 'piutang',
          tipeTempo: 'tanpa_tempo',
          tanggal: '2026-11-10',
          nominal: 1000000,
          keterangan: '',
          status: 'belum',
        ),
      );
    });
    await pumpDebts(tester, state);

    expect(find.widgetWithText(OutlinedButton, 'Hapus Seri'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hapus'), findsOneWidget);
  });

  testWidgets('batal di dialog hapus seri -> tidak ada yang terhapus', (
    tester,
  ) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() async {
      await state.addDebt(cicilan(id: 1000, ke: 1));
      await state.settleDebt(1000);
      await state.createNextInstallment(1000);
    });
    expect(state.debts.length, 2);
    await pumpDebts(tester, state);

    // Dua tile (satu aktif, satu di "Selesai").
    expect(find.text('Piutang Test'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus Seri').first);
    await tester.pumpAndSettle();

    // Dialog menampilkan jumlah baris + total nominal seri.
    expect(find.text('Hapus Satu Seri?'), findsOneWidget);
    expect(find.textContaining('2 baris cicilan'), findsOneWidget);
    expect(find.textContaining('Rp 10.000.000'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Piutang Test'), findsNWidgets(2));
    expect(state.debts.length, 2);
  });

  testWidgets('konfirmasi hapus seri -> seluruh seri hilang (aktif + lunas)', (
    tester,
  ) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() async {
      await state.addDebt(cicilan(id: 1000, ke: 1));
      await state.settleDebt(1000);
      await state.createNextInstallment(1000);
    });
    await pumpDebts(tester, state);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus Seri').first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Satu Seri?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Hapus Seri'));
    await waitGone(tester, 'Piutang Test');

    expect(find.text('Piutang Test'), findsNothing);
    expect(state.debts, isEmpty);
    // Kedua baris terantre sebagai delete (tombstone per baris saat push).
    final deletes = (await tester.runAsync(() => debtDeleteQueue()))!;
    expect(deletes.length, 2);
  });
}
