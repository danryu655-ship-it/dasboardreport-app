import 'package:dasboardreport/strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kunci string untuk ekspor gabung (laporan user 2026-11-07: Ekspor PDF +
/// Excel jadi satu) dan dialog "tidak ada data" harus ada di kedua bahasa,
/// dan versi tampil harus mengikuti pubspec (2.9.32).
void main() {
  test('kunci ekspor gabung + versi tampil ada di id dan en', () {
    const keys = [
      'export_data',
      'export_choose_format',
      'export_format_pdf_hint',
      'export_format_excel_hint',
      'export_no_data_title',
      'export_no_data',
      'app_version',
    ];
    for (final locale in ['id', 'en']) {
      final map = AppStrings.values[locale]!;
      for (final key in keys) {
        expect(map[key], isNotNull, reason: '$locale.$key hilang');
        expect(map[key]!.trim(), isNotEmpty, reason: '$locale.$key kosong');
      }
      expect(map['app_version'], 'DasboardReport v2.9.32');
      expect(map['export_no_data'], contains('{from}'));
      expect(map['export_no_data'], contains('{to}'));
    }
  });
}
