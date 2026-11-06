// Import Excel/CSV — perubahan 2026-11-06.
// Menguji: parser CSV (RFC 4180), parser XLSX, deteksi jenis file,
// validasi baris (tanggal/nominal/jenis wajib), baris TOTAL dilewati,
// dan template yang kolomnya sama persis dengan Ekspor Excel.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dasboardreport/services/export_service.dart';
import 'package:dasboardreport/services/import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsv', () {
    test('baris sederhana + CRLF', () {
      final rows = ImportService.parseCsv(
        'Tanggal,Keterangan,Jenis,Nominal\r\n2026-11-01,Gaji,pemasukan,5000000\r\n',
      );
      expect(rows.length, 2);
      expect(rows[1], ['2026-11-01', 'Gaji', 'pemasukan', '5000000']);
    });

    test('koma di dalam sel ber-kutip', () {
      final rows = ImportService.parseCsv(
        'Tanggal,Keterangan,Jenis,Nominal\n2026-11-01,"Makan, minum",pengeluaran,50000\n',
      );
      expect(rows[1][1], 'Makan, minum');
    });

    test('kutip ganda di dalam sel ber-kutip', () {
      final rows = ImportService.parseCsv(
        'A,B\n"kata ""penting""",2\n',
      );
      expect(rows[1][0], 'kata "penting"');
    });

    test('newline di dalam sel ber-kutip', () {
      final rows = ImportService.parseCsv(
        'A,B\n"baris1\nbaris2",2\n',
      );
      expect(rows.length, 2);
      expect(rows[1][0], 'baris1\nbaris2');
    });

    test('BOM UTF-8 diabaikan', () {
      final rows = ImportService.parseCsv('\uFEFFA,B\n1,2\n');
      expect(rows[0], ['A', 'B']);
    });
  });

  group('parseImportDate', () {
    test('ISO yyyy-MM-dd', () {
      expect(
        ImportService.parseImportDate('2026-11-05'),
        DateTime(2026, 11, 5),
      );
    });

    test('dd/MM/yyyy dan dd-MM-yyyy', () {
      expect(
        ImportService.parseImportDate('05/11/2026'),
        DateTime(2026, 11, 5),
      );
      expect(
        ImportService.parseImportDate('05-11-2026'),
        DateTime(2026, 11, 5),
      );
    });

    test('tanggal yang tidak ada ditolak', () {
      expect(ImportService.parseImportDate('31/02/2026'), isNull);
      expect(ImportService.parseImportDate('2026-02-31'), isNull);
      expect(ImportService.parseImportDate('2026-13-01'), isNull);
    });

    test('teks sampah ditolak', () {
      expect(ImportService.parseImportDate('kemarin'), isNull);
      expect(ImportService.parseImportDate(''), isNull);
    });
  });

  group('parseImportNominal', () {
    test('angka polos', () {
      expect(ImportService.parseImportNominal('5000000'), 5000000);
    });

    test('pemisah ribuan titik (Indonesia)', () {
      expect(ImportService.parseImportNominal('5.000.000'), 5000000);
    });

    test('awalan Rp dan spasi', () {
      expect(ImportService.parseImportNominal('Rp 5.000.000'), 5000000);
      expect(ImportService.parseImportNominal(' 5000000 '), 5000000);
    });

    test('desimal koma dibulatkan', () {
      expect(ImportService.parseImportNominal('2.500,75'), 2501);
    });

    test('bukan angka -> null', () {
      expect(ImportService.parseImportNominal('lima juta'), isNull);
      expect(ImportService.parseImportNominal(''), isNull);
      expect(ImportService.parseImportNominal('5.000.000,50,25'), isNull);
    });
  });

  group('detectKind', () {
    test('header transaksi dikenali', () {
      expect(
        ImportService.detectKind([
          'Tanggal',
          'Keterangan',
          'Kategori',
          'Metode',
          'Jenis',
          'Nominal',
        ]),
        ImportKind.transactions,
      );
    });

    test('header utang dikenali (case-insensitive)', () {
      expect(
        ImportService.detectKind([
          'tanggal',
          'partner',
          'jenis',
          'nominal',
          'keterangan',
          'status',
        ]),
        ImportKind.debts,
      );
    });

    test('header asing -> null', () {
      expect(ImportService.detectKind(['Nama', 'Umur']), isNull);
      expect(
        ImportService.detectKind(['Tanggal', 'Jenis', 'Nominal']),
        isNull,
      );
    });
  });

  group('parseTransactions', () {
    const csv =
        'Tanggal,Keterangan,Kategori,Metode,Jenis,Nominal\n'
        '2026-11-01,Gaji,Lainnya,Cash,pemasukan,5000000\n'
        '2026-11-02,Makan,Lainnya,Cash,pengeluaran,50000\n'
        'TOTAL,,,,,5050000\n';

    test('baris valid diimpor, baris TOTAL dilewati', () {
      final result = ImportService.parseTransactions(
        ImportService.parseCsv(csv),
        profile: 'Test',
      );
      expect(result.fileError, isNull);
      expect(result.valid.length, 2);
      expect(result.invalid, isEmpty);
      expect(result.valid[0].keterangan, 'Gaji');
      expect(result.valid[0].nominal, 5000000);
      expect(result.valid[1].jenis, 'pengeluaran');
    });

    test('baris tidak valid ditolak dengan alasan, baris lain tetap valid',
        () {
      const bad =
          'Tanggal,Keterangan,Kategori,Metode,Jenis,Nominal\n'
          '2026-11-01,OK,Lainnya,Cash,pemasukan,100000\n'
          '31/02/2026,Tanggal salah,Lainnya,Cash,pemasukan,100000\n'
          '2026-11-02,Nominal salah,Lainnya,Cash,pemasukan,abc\n'
          '2026-11-02,Jenis salah,Lainnya,Cash,tabungan,100000\n'
          '2026-11-02,,Lainnya,Cash,pemasukan,100000\n'
          '2026-11-02,Nominal nol,Lainnya,Cash,pemasukan,0\n';
      final result = ImportService.parseTransactions(
        ImportService.parseCsv(bad),
        profile: 'Test',
      );
      expect(result.valid.length, 1);
      expect(result.invalid.length, 5);
      expect(result.invalid.map((e) => e.rowNumber), [3, 4, 5, 6, 7]);
      expect(result.invalid[0].message, contains('tanggal'));
      expect(result.invalid[1].message, contains('nominal'));
      expect(result.invalid[2].message, contains('jenis'));
      expect(result.invalid[3].message, contains('keterangan'));
      expect(result.invalid[4].message, contains('nominal'));
    });

    test('kategori/metode kosong memakai default', () {
      const minimal =
          'Tanggal,Keterangan,Kategori,Metode,Jenis,Nominal\n'
          '2026-11-01,Test,,,pemasukan,1000\n';
      final result = ImportService.parseTransactions(
        ImportService.parseCsv(minimal),
        profile: 'Test',
      );
      expect(result.valid.length, 1);
      expect(result.valid.first.kategori, 'Lainnya');
      expect(result.valid.first.metodePembayaran, 'Cash');
    });

    test('header salah -> fileError, file kosong -> fileError', () {
      final wrong = ImportService.parseTransactions(
        ImportService.parseCsv('Nama,Umur\nDan,30\n'),
        profile: 'Test',
      );
      expect(wrong.fileError, isNotNull);
      expect(wrong.valid, isEmpty);
      final empty = ImportService.parseTransactions([], profile: 'Test');
      expect(empty.fileError, isNotNull);
    });
  });

  group('parseDebts', () {
    const csv =
        'Tanggal,Partner,Jenis,Nominal,Keterangan,Status\n'
        '2026-11-01,Budi,piutang,1000000,Pinjam,belum\n'
        '2026-11-02,Ani,utang,500000,,sudah\n';

    test('baris valid diimpor, status dipertahankan', () {
      final result = ImportService.parseDebts(
        ImportService.parseCsv(csv),
        profile: 'Test',
      );
      expect(result.fileError, isNull);
      expect(result.valid.length, 2);
      expect(result.invalid, isEmpty);
      expect(result.valid[0].partnerName, 'Budi');
      expect(result.valid[0].status, 'belum');
      expect(result.valid[1].status, 'sudah');
    });

    test('status lunas dipetakan ke sudah; status asing ditolak', () {
      const rows =
          'Tanggal,Partner,Jenis,Nominal,Keterangan,Status\n'
          '2026-11-01,Budi,piutang,1000,,lunas\n'
          '2026-11-01,Ani,utang,1000,,ngutang\n'
          '2026-11-01,,piutang,1000,,belum\n';
      final result = ImportService.parseDebts(
        ImportService.parseCsv(rows),
        profile: 'Test',
      );
      expect(result.valid.length, 1);
      expect(result.valid.first.status, 'sudah');
      expect(result.invalid.length, 2);
    });
  });

  group('template (kolom sama persis dengan ekspor)', () {
    test('header template transaksi == header ekspor', () {
      final template = ImportService.transactionTemplateCsv();
      final header = template.split('\n').first.trim();
      expect(header, ExportService.transactionCsvHeader);
    });

    test('header template utang == header ekspor', () {
      final template = ImportService.debtTemplateCsv();
      final header = template.split('\n').first.trim();
      expect(header, ExportService.debtCsvHeader);
    });

    test('template transaksi bisa diparse kembali (round-trip)', () {
      final result = ImportService.parseTransactions(
        ImportService.parseCsv(ImportService.transactionTemplateCsv()),
        profile: 'Test',
      );
      expect(result.fileError, isNull);
      expect(result.valid.length, 2);
    });

    test('template utang bisa diparse kembali (round-trip)', () {
      final result = ImportService.parseDebts(
        ImportService.parseCsv(ImportService.debtTemplateCsv()),
        profile: 'Test',
      );
      expect(result.fileError, isNull);
      expect(result.valid.length, 2);
    });
  });

  group('parseXlsx', () {
    // Bangun .xlsx minimal langsung dari XML + ZIP (tanpa package excel,
    // yang tidak kompatibel dengan archive 4.x): header + 1 baris data
    // dengan tanggal serial Excel (46327 = 2026-11-01) ber-style tanggal.
    Uint8List buildTestXlsx() {
      const workbook =
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
          '</workbook>';
      const rels =
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '</Relationships>';
      const sharedStrings =
          '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="10" uniqueCount="10">'
          '<si><t>Tanggal</t></si>'
          '<si><t>Keterangan</t></si>'
          '<si><t>Kategori</t></si>'
          '<si><t>Metode</t></si>'
          '<si><t>Jenis</t></si>'
          '<si><t>Nominal</t></si>'
          '<si><t>Gaji XLSX</t></si>'
          '<si><t>Lainnya</t></si>'
          '<si><t>Cash</t></si>'
          '<si><t>pemasukan</t></si>'
          '</sst>';
      const styles =
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<numFmts count="1"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/></numFmts>'
          '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
          '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
          '<borders count="1"><border/></borders>'
          '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
          '<cellXfs count="2">'
          '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
          '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
          '</cellXfs>'
          '</styleSheet>';
      const sheet =
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<sheetData>'
          '<row r="1">'
          '<c r="A1" t="s"><v>0</v></c>'
          '<c r="B1" t="s"><v>1</v></c>'
          '<c r="C1" t="s"><v>2</v></c>'
          '<c r="D1" t="s"><v>3</v></c>'
          '<c r="E1" t="s"><v>4</v></c>'
          '<c r="F1" t="s"><v>5</v></c>'
          '</row>'
          '<row r="2">'
          '<c r="A2" s="1"><v>46327</v></c>'
          '<c r="B2" t="s"><v>6</v></c>'
          '<c r="C2" t="s"><v>7</v></c>'
          '<c r="D2" t="s"><v>8</v></c>'
          '<c r="E2" t="s"><v>9</v></c>'
          '<c r="F2"><v>7000000</v></c>'
          '</row>'
          '</sheetData>'
          '</worksheet>';
      final archive = Archive();
      void add(String name, String content) {
        final data = utf8.encode(content);
        archive.addFile(ArchiveFile(name, data.length, data));
      }

      add('xl/workbook.xml', workbook);
      add('xl/_rels/workbook.xml.rels', rels);
      add('xl/sharedStrings.xml', sharedStrings);
      add('xl/styles.xml', styles);
      add('xl/worksheets/sheet1.xml', sheet);
      return Uint8List.fromList(ZipEncoder().encode(archive));
    }

    test('sheet pertama dibaca: shared string + angka + tanggal serial', () {
      final rows = ImportService.parseXlsx(buildTestXlsx());
      expect(rows.length, 2);
      expect(rows[0], [
        'Tanggal',
        'Keterangan',
        'Kategori',
        'Metode',
        'Jenis',
        'Nominal',
      ]);
      expect(rows[1][0], '2026-11-01');
      expect(rows[1][1], 'Gaji XLSX');
      expect(rows[1][5], '7000000');
    });

    test('baris xlsx divalidasi seperti CSV', () {
      final result = ImportService.parseTransactions(
        ImportService.parseXlsx(buildTestXlsx()),
        profile: 'Test',
      );
      expect(result.fileError, isNull);
      expect(result.valid.length, 1);
      expect(result.valid.first.keterangan, 'Gaji XLSX');
      expect(result.valid.first.nominal, 7000000);
      expect(result.valid.first.tanggal, '2026-11-01');
    });

    test('parseFile menolak ekstensi tak didukung', () {
      expect(
        ImportService.parseFile(
          fileName: 'data.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        isNull,
      );
    });

    test('parseFile membaca .xlsx berdasarkan ekstensi', () {
      final rows = ImportService.parseFile(
        fileName: 'laporan.xlsx',
        bytes: buildTestXlsx(),
      );
      expect(rows, isNotNull);
      expect(rows?.length, 2);
    });
  });
}
