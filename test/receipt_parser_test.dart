import 'package:dasboardreport/screens/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseReceiptText (port scanStrukAI web)', () {
    test('struk BCA QRIS: nominal Rp, tanggal, bank, metode, merchant', () {
      const text = '''
INDOMARET
Jl. Merdeka No. 12
12/11/2026 14:32
BELANJA HARIAN
TOTAL BELANJA Rp 125.500
QRIS BCA
BERHASIL
''';
      final r = parseReceiptText(text);
      expect(r.nominal, 125500);
      expect(r.tanggal, DateTime(2026, 11, 12));
      expect(r.bank, 'BCA');
      expect(r.metode, 'QR');
      expect(r.keterangan, 'BELANJA HARIAN');
    });

    test('nominal dari baris TOTAL bila tanpa Rp', () {
      const text = '''
TOKO KELONTONG
01/02/2026
TOTAL 87.250
TUNAI
''';
      final r = parseReceiptText(text);
      expect(r.nominal, 87250);
      expect(r.metode, 'Cash');
    });

    test('nominal dari angka ribuan terbesar bila tanpa TOTAL/Rp', () {
      const text = '''
STRUK BELANJA
05/03/2026
Item A 15000
Item B 250000
Item C 5000
''';
      final r = parseReceiptText(text);
      expect(r.nominal, 250000);
    });

    test('bank Mandiri + transfer terdeteksi', () {
      const text = '''
TRANSFER
15/04/2026
MANDIRI
Rp 1.000.000
TRF
''';
      final r = parseReceiptText(text);
      expect(r.bank, 'Mandiri');
      expect(r.metode, 'Transfer Bank');
      expect(r.nominal, 1000000);
    });

    test('teks kosong menghasilkan semua null', () {
      final r = parseReceiptText('');
      expect(r.nominal, isNull);
      expect(r.tanggal, isNull);
      expect(r.metode, isNull);
      expect(r.bank, isNull);
      expect(r.keterangan, isNull);
    });
  });
}
