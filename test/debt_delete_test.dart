// Bug 1 — laporan user 2026-11-06: catatan utang/piutang yang dihapus
// masih tampil di bagian "Selesai" layar Hutang Piutang.
// Penyebab: tombol Hapus hanya tampil untuk baris BELUM lunas; baris yang
// sudah dilunasi tidak punya tombol Hapus sama sekali (berbeda dengan web,
// yang menampilkan Hapus di semua baris), sehingga cicilan yang sudah
// dilunasi tidak pernah bisa dihapus dan menetap di "Selesai".
// Regresi: hapus utang aktif -> hilang dari daftar aktif; hapus utang
// lunas -> hilang dari "Selesai"; tile lunas menampilkan tombol Hapus.
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
    // Form utang memakai DateFormat('d MMMM yyyy', 'id_ID') — data locale
    // harus diinisialisasi dulu di lingkungan test.
    await initializeDateFormatting('id_ID');
    // File DB sendiri per file test: `flutter test` menjalankan file
    // secara paralel, dan DatabaseHelper memakai satu jalur tetap.
    testDbDir = await Directory.systemTemp.createTemp(
      'dasboardreport_debt_delete_test_',
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

  Debt piutangTest({required int id}) => Debt(
    id: id,
    profile: 'Test',
    creatorName: 'Test',
    partnerName: 'Piutang Test',
    jenis: 'piutang',
    tipeTempo: 'cicilan',
    tenorBulan: 12,
    cicilanKe: 1,
    tanggal: '2026-11-10',
    nominal: 5000000,
    keterangan: '',
    status: 'belum',
    syncCode: '',
  );

  Future<void> pumpDebts(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: DebtsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('hapus utang aktif -> hilang dari daftar aktif', () async {
    final state = await freshState();
    await state.addDebt(piutangTest(id: 1000));
    expect(state.debts.length, 1);
    await state.deleteDebt(1000);
    expect(state.debts, isEmpty);
  });

  test('hapus utang LUNAS -> hilang dari "Selesai"', () async {
    final state = await freshState();
    await state.addDebt(piutangTest(id: 1000));
    // Lunasi: baris pindah ke bagian "Selesai".
    await state.settleDebt(1000);
    expect(state.debts.length, 1);
    expect(state.debts.first.isLunas, isTrue);
    // Hapus baris yang sudah lunas: harus hilang dari state sepenuhnya.
    await state.deleteDebt(1000);
    expect(state.debts, isEmpty);
  });

  testWidgets('tile lunas menampilkan tombol Hapus Seri (dan bukan Lunasi)', (
    tester,
  ) async {
    // Setup DB (async nyata via isolate ffi) HARUS di runAsync: di zona
    // fake-async testWidgets, await langsung menggantung.
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() async {
      await state.addDebt(piutangTest(id: 1000));
      await state.settleDebt(1000);
    });
    await pumpDebts(tester, state);

    expect(find.text('Piutang Test'), findsOneWidget);
    // Bagian "Selesai" tampil, tile lunas punya tombol Hapus Seri.
    expect(find.text('Selesai'), findsWidgets);

    expect(find.text('Piutang Test'), findsOneWidget);
    // Bagian "Selesai" tampil, tile lunas punya tombol Hapus Seri.
    expect(find.text('Selesai'), findsWidgets);
    expect(find.text('Hapus Seri'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Selesai'), findsNothing);
  });

  testWidgets('tile aktif menampilkan Lunasi + Hapus Seri', (tester) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() => state.addDebt(piutangTest(id: 1000)));
    await pumpDebts(tester, state);

    expect(find.text('Piutang Test'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Selesai'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hapus Seri'), findsOneWidget);
  });

  testWidgets('hapus lewat tile lunas -> hilang dari "Selesai"', (
    tester,
  ) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await tester.runAsync(() async {
      await state.addDebt(piutangTest(id: 1000));
      await state.settleDebt(1000);
    });
    await pumpDebts(tester, state);

    // Ketuk Hapus Seri pada tile lunas.
    await tester.tap(find.text('Hapus Seri'));
    await tester.pumpAndSettle();
    // Dialog konfirmasi muncul; ketuk Hapus Seri (tombol konfirmasi).
    // Pakai widgetWithText(TextButton, ...) — tombol tile adalah
    // OutlinedButton, jadi ini hanya cocok dengan tombol konfirmasi dialog.
    expect(find.text('Batal'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Hapus Seri'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Hapus Seri'));
    // Hapusan berjalan di SQLite (async nyata via isolate ffi) yang
    // dipicu dari tap handler (zona fake-async): selingi jeda nyata
    // (runAsync) dengan pump BERDURASI sampai TILE-nya hilang dari layar.
    // Jangan berhenti begitu `state.debts` kosong: _loadProfileData masih
    // menyelesaikan getLogs/getBugReports sesudah debts diisi, dan
    // notifyListeners (yang me-rebuild layar) baru jalan setelah itu —
    // loop yang berhenti di debts kosong akan mematikan rantai sebelum
    // notify. pump() tanpa durasi tidak memajukan animasi pop dialog,
    // sehingga future konfirmasi tak pernah selesai dan deleteDebt tak
    // pernah mulai.
    for (
      var i = 0;
      i < 30 && find.text('Piutang Test').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    // Timer debounce sync (2 detik) dibuat di zona fake-async oleh
    // recordChange saat hapus — harus dibiarkan jalan sampai selesai,
    // kalau tidak test gagal di teardown ("A Timer is still pending").
    // Di lingkungan test Supabase tidak terkonfigurasi sehingga syncNow()
    // langsung no-op.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Piutang Test'), findsNothing);
    expect(state.debts, isEmpty);
  });
}
