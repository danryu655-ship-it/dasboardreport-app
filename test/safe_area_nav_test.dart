// Pil navigasi harus tampil UTUH di atas system navigation bar Android,
// baik navigasi 3-tombol (viewPadding bawah ~48) maupun gesture bar
// (~16-24). Regresi dari laporan user 2026-11-06: pil tertutup tombol □ ○ ◁.
import 'package:dasboardreport/app_state.dart';
import 'package:dasboardreport/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester, double bottomPadding) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(800, 600),
              viewPadding: EdgeInsets.only(bottom: bottomPadding),
              padding: EdgeInsets.only(bottom: bottomPadding),
            ),
            child: const HomeShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Tinggi permukaan test default adalah 600.
  const surfaceHeight = 600.0;

  testWidgets('navigasi 3-tombol: pil di atas system bar (padding 48)', (
    tester,
  ) async {
    await pumpShell(tester, 48);
    final pill = find.byKey(const ValueKey('bottomNavPill'));
    expect(pill, findsOneWidget);
    final bottom = tester.getBottomRight(pill).dy;
    // Batas bawah pil harus di atas area system nav (600 - 48).
    expect(bottom, lessThanOrEqualTo(surfaceHeight - 48));
    // Dan pil harus tetap terlihat (tidak terdorong keluar layar).
    expect(bottom, greaterThan(surfaceHeight - 200));
  });

  testWidgets('gesture bar: pil di atas system bar (padding 24)', (
    tester,
  ) async {
    await pumpShell(tester, 24);
    final pill = find.byKey(const ValueKey('bottomNavPill'));
    expect(pill, findsOneWidget);
    final bottom = tester.getBottomRight(pill).dy;
    expect(bottom, lessThanOrEqualTo(surfaceHeight - 24));
    expect(bottom, greaterThan(surfaceHeight - 200));
  });

  testWidgets('tanpa system bar: pil tetap di dalam layar (padding 0)', (
    tester,
  ) async {
    await pumpShell(tester, 0);
    final pill = find.byKey(const ValueKey('bottomNavPill'));
    expect(pill, findsOneWidget);
    final bottom = tester.getBottomRight(pill).dy;
    expect(bottom, lessThanOrEqualTo(surfaceHeight));
    expect(bottom, greaterThan(surfaceHeight - 200));
  });

  testWidgets('pil dibungkus SafeArea', (tester) async {
    await pumpShell(tester, 48);
    final pill = find.byKey(const ValueKey('bottomNavPill'));
    final ancestor = find.ancestor(of: pill, matching: find.byType(SafeArea));
    expect(ancestor, findsWidgets);
  });
}
