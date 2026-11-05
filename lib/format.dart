import 'package:intl/intl.dart';

/// Format Rupiah — sama seperti web:
/// `new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR',
/// minimumFractionDigits: 0 })` → "Rp 1.500.000".
String formatRupiah(num value) {
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);
}

/// Format tanggal pendek ala web: `d MMM` locale id-ID (mis. "5 Nov").
String formatTanggalPendek(DateTime date) {
  return DateFormat('d MMM', 'id_ID').format(date);
}

/// Format tanggal ISO untuk penyimpanan (YYYY-MM-DD), sama seperti web.
String toIsoDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

/// Parse tanggal ISO; fallback ke hari ini bila tidak valid.
DateTime parseIsoDate(String value) {
  return DateTime.tryParse(value) ?? DateTime.now();
}

/// Nama bulan + tahun ala web (Inggris, mis. "September, 2026").
String formatBulanTahun(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]}, ${date.year}';
}

/// Format ribuan Indonesia (1.500.000) untuk input nominal.
String formatThousands(int value) {
  return NumberFormat('#,##0', 'id_ID').format(value);
}

/// Parse teks nominal (boleh berisi titik pemisah ribuan) menjadi int.
int parseNominal(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}
