// Regresi crash QRIS (laporan user 2026-11-06 23:43):
// memilih metode pembayaran QR di form transaksi membuat layar merah
// "Bad state: No element" karena `_bankList` mengembalikan [] untuk QR
// lalu `_bankList.first` dipanggil. Perilaku yang benar (cerminan web):
// QR memakai daftar bank transfer, dan dropdown tidak pernah melempar
// untuk daftar kosong.
import 'dart:io';

import 'package:dasboardreport/app_state.dart';
import 'package:dasboardreport/db.dart';
import 'package:dasboardreport/screens/transaction_form_screen.dart';
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
      'dasboardreport_trx_qr_test_',
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

  Future<void> pumpForm(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TransactionFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  DropdownButton<String> metodeDropdown(WidgetTester tester) =>
      tester.widget<DropdownButton<String>>(
        find.byWidgetPredicate(
          (w) => w is DropdownButton<String> && w.value == 'Cash',
        ),
      );

  testWidgets('Memilih metode QR tidak crash dan menampilkan daftar bank',
      (WidgetTester tester) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await pumpForm(tester, state);

    // Awal: metode Cash, tidak ada dropdown bank.
    expect(find.text('Danamon'), findsNothing);

    // Buka dropdown metode dan pilih QR.
    await tester.tap(find.byWidget(metodeDropdown(tester)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QR').last);
    await tester.pumpAndSettle();

    // Tidak ada exception selama build ulang, dan bank asal terisi
    // opsi pertama daftar bank transfer (cerminan web).
    expect(tester.takeException(), isNull);
    expect(find.text('Danamon'), findsOneWidget);
  });

  testWidgets('Simpan transaksi QR menyimpan bank asal', (
    WidgetTester tester,
  ) async {
    final state = (await tester.runAsync(() => freshState()))!;
    await pumpForm(tester, state);

    await tester.tap(find.byWidget(metodeDropdown(tester)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QR').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '50000');
    await tester.enterText(fields.last, 'Belanja QRIS');
    await tester.pump();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Simpan'));
    // Simpan berjalan async (beberapa tulis/baca DB via isolate sqflite).
    // Pola yang sama dengan waitGone di debt test: selingi jeda NYATA
    // (runAsync, agar reply isolate tiba) dengan pump (agar kelanjutan
    // di zona fake-async berjalan). Pump saja tidak cukup; runAsync saja
    // juga tidak (tiap ronde butuh satu pump).
    for (var i = 0; i < 30 && state.transactions.isEmpty; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Timer debounce sync 2 detik masih tertunda; majukan jam fake agar
    // timer itu jalan (pola waitGone di debt test).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(state.transactions.length, 1);
    final trx = state.transactions.first;
    expect(trx.metodePembayaran, 'QR');
    expect(trx.detailBank, 'Danamon');
    expect(trx.nominal, 50000);
  });
}
