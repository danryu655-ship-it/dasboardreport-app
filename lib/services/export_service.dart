import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../format.dart';
import '../models.dart';

/// Export lokal — cerminan `exportPDF()` / `exportExcel()` di web:
/// PDF format neraca (judul "LAPORAN KEUANGAN KELOMPOK", profil, periode,
/// tabel tanggal/keterangan/kategori/metode/pemasukan/pengeluaran + kotak
/// total); Excel = CSV (kolom Tanggal,Keterangan,Kategori,Metode,Jenis,
/// Nominal + baris TOTAL; jenis 'utang' mengekspor daftar utang).
/// Semua file ditulis ke direktori dokumen aplikasi, lalu dibagikan/disimpan
/// lewat share sheet — tanpa server, tanpa API.
class ExportService {
  static Future<File> exportPdf({
    required String profile,
    required String jenis,
    required DateTime from,
    required DateTime to,
    required List<AppTransaction> transactions,
    required List<Debt> debts,
  }) async {
    final rows = _filtered(transactions, debts, jenis, from, to);
    final totalMasuk = rows
        .where((r) => r.$1 == 'pemasukan')
        .fold<int>(0, (s, r) => s + r.$2.nominal);
    final totalKeluar = rows
        .where((r) => r.$1 == 'pengeluaran')
        .fold<int>(0, (s, r) => s + r.$2.nominal);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              'LAPORAN KEUANGAN KELOMPOK',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('Profil: $profile')),
          pw.Center(
            child: pw.Text('Periode: ${_fmtDate(from)} s/d ${_fmtDate(to)}'),
          ),
          pw.Center(child: pw.Text('Jenis: ${_jenisLabel(jenis)}')),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Tanggal',
              'Keterangan',
              'Kategori',
              'Metode',
              'Pemasukan',
              'Pengeluaran',
            ],
            data: [
              for (final r in rows)
                [
                  _fmtDate(parseIsoDate(r.$2.tanggal)),
                  r.$2.keterangan,
                  r.$2.kategori,
                  r.$2.metodePembayaran,
                  r.$1 == 'pemasukan' ? formatRupiah(r.$2.nominal) : '',
                  r.$1 == 'pengeluaran' ? formatRupiah(r.$2.nominal) : '',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Total Pemasukan: ${formatRupiah(totalMasuk)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Total Pengeluaran: ${formatRupiah(totalKeluar)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Selisih: ${formatRupiah(totalMasuk - totalKeluar)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan-${toIsoDate(DateTime.now())}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static Future<File> exportCsv({
    required String profile,
    required String jenis,
    required DateTime from,
    required DateTime to,
    required List<AppTransaction> transactions,
    required List<Debt> debts,
  }) async {
    final buf = StringBuffer();
    if (jenis == 'utang') {
      buf.writeln('Tanggal,Partner,Jenis,Nominal,Keterangan,Status');
      final list =
          debts
              .where((d) => _inRange(parseIsoDate(d.tanggal), from, to))
              .toList()
            ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
      var total = 0;
      for (final d in list) {
        total += d.nominal;
        buf.writeln(
          _csvRow([
            d.tanggal,
            d.partnerName,
            d.jenis,
            d.nominal.toString(),
            d.keterangan,
            d.status,
          ]),
        );
      }
      buf.writeln(_csvRow(['TOTAL', '', '', total.toString(), '', '']));
    } else {
      buf.writeln('Tanggal,Keterangan,Kategori,Metode,Jenis,Nominal');
      final rows = _filtered(transactions, debts, jenis, from, to);
      var total = 0;
      for (final r in rows) {
        total += r.$2.nominal;
        buf.writeln(
          _csvRow([
            r.$2.tanggal,
            r.$2.keterangan,
            r.$2.kategori,
            r.$2.metodePembayaran,
            r.$1,
            r.$2.nominal.toString(),
          ]),
        );
      }
      buf.writeln(_csvRow(['TOTAL', '', '', '', '', total.toString()]));
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan-${toIsoDate(DateTime.now())}.csv');
    await file.writeAsString(buf.toString());
    return file;
  }

  /// Baris terfilter + terurut (tanggal naik) untuk jenis yang dipilih.
  /// Mengembalikan pasangan (jenis, transaksi) agar utang/piutang tidak
  /// tercampur — untuk PDF/CSV transaksi saja.
  static List<(String, AppTransaction)> _filtered(
    List<AppTransaction> transactions,
    List<Debt> debts,
    String jenis,
    DateTime from,
    DateTime to,
  ) {
    final rows =
        transactions
            .where((t) {
              if (jenis != 'semua' && t.jenis != jenis) return false;
              return _inRange(parseIsoDate(t.tanggal), from, to);
            })
            .map((t) => (t.jenis, t))
            .toList()
          ..sort((a, b) => a.$2.tanggal.compareTo(b.$2.tanggal));
    return rows;
  }

  static bool _inRange(DateTime d, DateTime from, DateTime to) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(DateTime(from.year, from.month, from.day)) &&
        !day.isAfter(DateTime(to.year, to.month, to.day));
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _jenisLabel(String jenis) {
    switch (jenis) {
      case 'pemasukan':
        return 'Pemasukan';
      case 'pengeluaran':
        return 'Pengeluaran';
      case 'utang':
        return 'Utang / Piutang';
      default:
        return 'Semua';
    }
  }

  static String _csvRow(List<String> cells) {
    return cells.map((c) => '"${c.replaceAll('"', '""')}"').join(',');
  }
}
