// Smoke test fase 1: aplikasi dapat dibangun dan menampilkan layar awal
// (welcome / kunci PIN / dashboard, tergantung state).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dasboardreport/main.dart';

void main() {
  testWidgets('Aplikasi DasboardReport dapat di-build', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DasboardReportApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
