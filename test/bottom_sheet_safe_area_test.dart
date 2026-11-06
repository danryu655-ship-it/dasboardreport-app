// Bug 2 — laporan user 2026-11-06: tombol "Simpan" di lembar bawah
// "Tambah Utang / Piutang" TERTUTUP system navigation bar Android.
// Penyebab: padding bawah sheet hanya 20 + keyboard inset, tanpa SafeArea.
// Regresi: tombol Simpan harus tampil UTUH di atas system bar, baik
// navigasi 3-tombol (padding bawah ~48) maupun gesture bar (~24).
// Pola yang sama diperbaiki juga di form tagihan + 2 sheet dashboard.
import 'package:dasboardreport/app_state.dart';
import 'package:dasboardreport/screens/bills_screen.dart';
import 'package:dasboardreport/screens/debts_screen.dart';
import 'package:dasboardreport/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    // Form memakai DateFormat('d MMMM yyyy', 'id_ID') — data locale harus
    // diinisialisasi dulu di lingkungan test.
    await initializeDateFormatting('id_ID');
  });

  // Tinggi permukaan test default adalah 600.
  const surfaceHeight = 600.0;

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen,
    double bottomPadding,
  ) async {
    // Inset HARUS di level view test, bukan pembungkus MediaQuery di home:
    // modal bottom sheet dirender oleh Navigator (di ATAS home), sehingga
    // MediaQuery di home tidak menjangkau isi sheet — di perangkat nyata
    // inset berasal dari view sistem dan berlaku untuk semua route.
    // FakeViewPadding memakai piksel FISIK: kalikan dengan devicePixelRatio
    // test (3.0) supaya 48 logis tetap 48 logis (48 fisik = 16 logis).
    final dpr = tester.view.devicePixelRatio;
    tester.view.padding = FakeViewPadding(bottom: bottomPadding * dpr);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomPadding * dpr);
    addTearDown(() {
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openFormSheet(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(AppButton), findsOneWidget);
  }

  void expectSaveButtonAboveSystemBar(
    WidgetTester tester,
    double bottomPadding,
  ) {
    final button = find.byType(AppButton);
    final bottom = tester.getBottomRight(button).dy;
    // Batas bawah tombol harus di atas area system nav.
    expect(bottom, lessThanOrEqualTo(surfaceHeight - bottomPadding));
    // Dan tombol harus tetap terlihat (tidak terdorong keluar layar).
    expect(bottom, greaterThan(surfaceHeight - 250));
  }

  group('form Utang / Piutang', () {
    testWidgets('navigasi 3-tombol: Simpan di atas system bar (padding 48)',
        (tester) async {
      await pumpScreen(tester, const DebtsScreen(), 48);
      await openFormSheet(tester);
      expect(find.text('Simpan'), findsOneWidget);
      expectSaveButtonAboveSystemBar(tester, 48);
    });

    testWidgets('gesture bar: Simpan di atas system bar (padding 24)',
        (tester) async {
      await pumpScreen(tester, const DebtsScreen(), 24);
      await openFormSheet(tester);
      expectSaveButtonAboveSystemBar(tester, 24);
    });

    testWidgets('tanpa system bar: Simpan tetap di dalam layar (padding 0)',
        (tester) async {
      await pumpScreen(tester, const DebtsScreen(), 0);
      await openFormSheet(tester);
      expectSaveButtonAboveSystemBar(tester, 0);
    });
  });

  group('form Tagihan (pola yang sama)', () {
    testWidgets('navigasi 3-tombol: Simpan di atas system bar (padding 48)',
        (tester) async {
      await pumpScreen(tester, const BillsScreen(), 48);
      await openFormSheet(tester);
      expect(find.text('Simpan'), findsOneWidget);
      expectSaveButtonAboveSystemBar(tester, 48);
    });

    testWidgets('gesture bar: Simpan di atas system bar (padding 24)',
        (tester) async {
      await pumpScreen(tester, const BillsScreen(), 24);
      await openFormSheet(tester);
      expectSaveButtonAboveSystemBar(tester, 24);
    });
  });
}
