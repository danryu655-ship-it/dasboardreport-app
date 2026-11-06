import 'dart:convert';
import 'dart:typed_data';

import '../format.dart';
import '../models.dart';
import 'export_service.dart';
import 'xlsx_reader.dart';

/// Impor Excel/CSV — kebalikan dari ExportService.exportCsv():
/// membaca file CSV (format persis kolom ekspor) atau XLSX, memvalidasi tiap
/// baris, lalu mengembalikan baris valid + baris bermasalah beserta alasannya.
/// Impor TIDAK PERNAH mengubah/menghapus data yang sudah ada: semua baris
/// valid masuk sebagai catatan BARU (id baru dari AppState) dan ikut antrean
/// sync seperti data biasa.
///
/// Aturan validasi (wajib):
/// - header kolom harus dikenali (transaksi atau utang/piutang);
/// - Tanggal wajib + valid (ISO yyyy-MM-dd, atau dd/MM/yyyy, dd-MM-yyyy);
/// - Nominal wajib angka > 0 (menerima "5.000.000", "Rp 5.000.000", "5000000");
/// - Jenis wajib: pemasukan/pengeluaran (transaksi) atau utang/piutang;
/// - baris TOTAL dari ekspor dilewati (bukan data);
/// - baris tidak valid ditolak dengan pesan jelas, baris lain tetap diimpor.
enum ImportKind { transactions, debts }

class ImportRowError {
  /// Nomor baris di file (1-based, header = baris 1).
  final int rowNumber;
  final String message;

  const ImportRowError(this.rowNumber, this.message);
}

class ImportParseResult<T> {
  /// null bila header tidak dikenali / file tidak bisa dibaca.
  final ImportKind? kind;
  final List<T> valid;
  final List<ImportRowError> invalid;

  /// Kesalahan level file (bukan per baris), mis. header tidak dikenali.
  final String? fileError;

  const ImportParseResult({
    required this.kind,
    required this.valid,
    required this.invalid,
    this.fileError,
  });

  bool get hasFileError => fileError != null;
}

class ImportService {
  // ---------- Parser CSV (RFC 4180) ----------
  // Mendukung sel ber-tanda-kutip, koma di dalam kutip, kutip ganda (""),
  // newline di dalam kutip, CRLF/LF, dan BOM UTF-8.

  static List<List<String>> parseCsv(String text) {
    final clean = text.replaceAll('\uFEFF', '');
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < clean.length) {
      final c = clean[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < clean.length && clean[i + 1] == '"') {
            cell.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i++;
          continue;
        }
        cell.write(c);
        i++;
        continue;
      }
      if (c == '"') {
        inQuotes = true;
        i++;
        continue;
      }
      if (c == ',') {
        row.add(cell.toString());
        cell.clear();
        i++;
        continue;
      }
      if (c == '\r' || c == '\n') {
        if (c == '\r' && i + 1 < clean.length && clean[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
        i++;
        continue;
      }
      cell.write(c);
      i++;
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    rows.removeWhere((r) => r.every((c) => c.trim().isEmpty));
    return rows;
  }

  // ---------- Parser XLSX (sheet pertama, via XlsxReader) ----------

  static List<List<String>> parseXlsx(Uint8List bytes) {
    return XlsxReader.readRows(bytes);
  }

  // ---------- Entry point file ----------

  /// Membaca bytes file berdasarkan ekstensi (.csv / .xlsx) menjadi baris
  /// mentah (baris pertama = header). Mengembalikan null bila ekstensi
  /// tidak didukung atau isi tidak bisa dibaca.
  static List<List<String>>? parseFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    final lower = fileName.toLowerCase();
    try {
      if (lower.endsWith('.csv')) {
        final text = _decodeCsvText(bytes);
        return parseCsv(text);
      }
      if (lower.endsWith('.xlsx')) return parseXlsx(bytes);
    } catch (_) {
      return null;
    }
    return null;
  }

  /// CSV dari Excel Windows sering tersimpan sebagai windows-1252 (bukan
  /// UTF-8): coba UTF-8 dulu, jatuh ke latin1 bila gagal.
  static String _decodeCsvText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  // ---------- Deteksi jenis file ----------

  static ImportKind? detectKind(List<String> header) {
    final cols = header.map((c) => c.trim().toLowerCase()).toSet();
    if (cols.contains('tanggal') &&
        cols.contains('partner') &&
        cols.contains('jenis') &&
        cols.contains('nominal')) {
      return ImportKind.debts;
    }
    if (cols.contains('tanggal') &&
        cols.contains('keterangan') &&
        cols.contains('jenis') &&
        cols.contains('nominal')) {
      return ImportKind.transactions;
    }
    return null;
  }

  // ---------- Validasi ----------

  /// Tanggal impor: ISO yyyy-MM-dd (format ekspor), dd/MM/yyyy,
  /// dd-MM-yyyy, atau yyyy/MM/dd. Mengembalikan null bila tidak valid —
  /// termasuk tanggal yang tidak ada (mis. 31/02/2026).
  static DateTime? parseImportDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (iso != null) {
      return _checkedDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final ymd = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(s);
    if (ymd != null) {
      return _checkedDate(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
      );
    }
    final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(s);
    if (dmy != null) {
      return _checkedDate(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }
    return null;
  }

  static DateTime? _checkedDate(int year, int month, int day) {
    if (year < 2000 || year > 2100 || month < 1 || month > 12) return null;
    final d = DateTime(year, month, day);
    if (d.year != year || d.month != month || d.day != day) return null;
    return d;
  }

  /// Nominal impor (konvensi Indonesia): titik = pemisah ribuan, koma =
  /// desimal. Menerima "5000000", "5.000.000", "Rp 5.000.000",
  /// "5.000.000,50". Mengembalikan null bila bukan angka; <= 0 ditolak
  /// oleh pemanggil.
  static int? parseImportNominal(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(RegExp('rp', caseSensitive: false), '').trim();
    s = s.replaceAll(' ', '').replaceAll('\u00A0', '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      final parts = s.split(',');
      if (parts.length != 2) return null;
      final intPart = parts[0].replaceAll('.', '');
      final value = double.tryParse('$intPart.${parts[1]}');
      return value?.round();
    }
    s = s.replaceAll('.', '');
    final intValue = int.tryParse(s);
    if (intValue != null) return intValue;
    return double.tryParse(s)?.round();
  }

  static ImportParseResult<AppTransaction> parseTransactions(
    List<List<String>> rows, {
    required String profile,
  }) {
    if (rows.isEmpty) {
      return const ImportParseResult(
        kind: null,
        valid: [],
        invalid: [],
        fileError: 'File kosong.',
      );
    }
    final header = rows.first;
    if (detectKind(header) != ImportKind.transactions) {
      return const ImportParseResult(
        kind: null,
        valid: [],
        invalid: [],
        fileError:
            'Header tidak dikenali. Gunakan template Transaksi '
            '(Tanggal,Keterangan,Kategori,Metode,Jenis,Nominal).',
      );
    }
    final col = _columnIndex(header);
    final valid = <AppTransaction>[];
    final invalid = <ImportRowError>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 1;
      if (_isTotalRow(row) || _isEmptyRow(row)) continue;
      final errors = <String>[];
      final tanggal = parseImportDate(_cell(row, col, 'tanggal'));
      if (tanggal == null) errors.add('tanggal tidak valid');
      final keterangan = _cell(row, col, 'keterangan').trim();
      if (keterangan.isEmpty) errors.add('keterangan kosong');
      final jenis = _cell(row, col, 'jenis').trim().toLowerCase();
      if (jenis != 'pemasukan' && jenis != 'pengeluaran') {
        errors.add('jenis harus pemasukan/pengeluaran');
      }
      final nominal = parseImportNominal(_cell(row, col, 'nominal'));
      if (nominal == null) {
        errors.add('nominal bukan angka');
      } else if (nominal <= 0) {
        errors.add('nominal harus lebih dari 0');
      }
      if (errors.isNotEmpty) {
        invalid.add(ImportRowError(rowNumber, errors.join('; ')));
        continue;
      }
      valid.add(
        AppTransaction(
          // id = 0: penanda "baru" — AppState memberi id baru saat impor.
          id: 0,
          profile: profile,
          jenis: jenis,
          tanggal: toIsoDate(tanggal!),
          kategori: _cell(row, col, 'kategori').trim().isEmpty
              ? 'Lainnya'
              : _cell(row, col, 'kategori').trim(),
          metodePembayaran: _cell(row, col, 'metode').trim().isEmpty
              ? 'Cash'
              : _cell(row, col, 'metode').trim(),
          keterangan: keterangan,
          nominal: nominal!,
        ),
      );
    }
    return ImportParseResult(
      kind: ImportKind.transactions,
      valid: valid,
      invalid: invalid,
    );
  }

  static ImportParseResult<Debt> parseDebts(
    List<List<String>> rows, {
    required String profile,
  }) {
    if (rows.isEmpty) {
      return const ImportParseResult(
        kind: null,
        valid: [],
        invalid: [],
        fileError: 'File kosong.',
      );
    }
    final header = rows.first;
    if (detectKind(header) != ImportKind.debts) {
      return const ImportParseResult(
        kind: null,
        valid: [],
        invalid: [],
        fileError:
            'Header tidak dikenali. Gunakan template Utang/Piutang '
            '(Tanggal,Partner,Jenis,Nominal,Keterangan,Status).',
      );
    }
    final col = _columnIndex(header);
    final valid = <Debt>[];
    final invalid = <ImportRowError>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNumber = i + 1;
      if (_isTotalRow(row) || _isEmptyRow(row)) continue;
      final errors = <String>[];
      final tanggal = parseImportDate(_cell(row, col, 'tanggal'));
      if (tanggal == null) errors.add('tanggal tidak valid');
      final partner = _cell(row, col, 'partner').trim();
      if (partner.isEmpty) errors.add('partner kosong');
      final jenis = _cell(row, col, 'jenis').trim().toLowerCase();
      if (jenis != 'utang' && jenis != 'piutang') {
        errors.add('jenis harus utang/piutang');
      }
      final nominal = parseImportNominal(_cell(row, col, 'nominal'));
      if (nominal == null) {
        errors.add('nominal bukan angka');
      } else if (nominal <= 0) {
        errors.add('nominal harus lebih dari 0');
      }
      final statusRaw = _cell(row, col, 'status').trim().toLowerCase();
      var status = 'belum';
      if (statusRaw.isEmpty || statusRaw == 'belum') {
        status = 'belum';
      } else if (statusRaw == 'sudah' ||
          statusRaw == 'lunas' ||
          statusRaw == 'selesai') {
        status = 'sudah';
      } else {
        errors.add('status harus belum/sudah');
      }
      if (errors.isNotEmpty) {
        invalid.add(ImportRowError(rowNumber, errors.join('; ')));
        continue;
      }
      valid.add(
        Debt(
          // id = 0: penanda "baru" — AppState memberi id baru saat impor.
          id: 0,
          profile: profile,
          creatorName: profile,
          partnerName: partner,
          jenis: jenis,
          tipeTempo: 'tanpa_tempo',
          tenorBulan: null,
          cicilanKe: null,
          tanggal: toIsoDate(tanggal!),
          nominal: nominal!,
          keterangan: _cell(row, col, 'keterangan').trim(),
          status: status,
          syncCode: '',
        ),
      );
    }
    return ImportParseResult(
      kind: ImportKind.debts,
      valid: valid,
      invalid: invalid,
    );
  }

  static Map<String, int> _columnIndex(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      map[header[i].trim().toLowerCase()] = i;
    }
    return map;
  }

  static String _cell(
    List<String> row,
    Map<String, int> col,
    String name,
  ) {
    final idx = col[name];
    if (idx == null || idx >= row.length) return '';
    return row[idx];
  }

  static bool _isTotalRow(List<String> row) {
    return row.isNotEmpty && row.first.trim().toLowerCase() == 'total';
  }

  static bool _isEmptyRow(List<String> row) {
    return row.every((c) => c.trim().isEmpty);
  }

  // ---------- Template (kolom SAMA PERSIS dengan ekspor) ----------

  /// Template CSV transaksi — header diambil dari ExportService supaya
  /// selalu sama persis dengan Ekspor Excel.
  static String transactionTemplateCsv() {
    final buf = StringBuffer();
    buf.writeln(ExportService.transactionCsvHeader);
    buf.writeln(
      '"2026-11-01","CONTOH - HAPUS BARIS INI","Lainnya","Cash","pemasukan","100000"',
    );
    buf.writeln(
      '"2026-11-02","CONTOH - HAPUS BARIS INI","Lainnya","Cash","pengeluaran","50000"',
    );
    return buf.toString();
  }

  static String debtTemplateCsv() {
    final buf = StringBuffer();
    buf.writeln(ExportService.debtCsvHeader);
    buf.writeln(
      '"2026-11-01","CONTOH - HAPUS BARIS INI","piutang","1000000","","belum"',
    );
    buf.writeln(
      '"2026-11-02","CONTOH - HAPUS BARIS INI","utang","500000","","belum"',
    );
    return buf.toString();
  }
}
