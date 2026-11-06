import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Pembaca XLSX minimal (read-only) untuk Impor Excel.
///
/// Menggantikan package `excel` 4.0.6 yang TIDAK KOMPATIBEL dengan
/// `archive` 4.x (dipakai `pdf`/`image` di proyek ini): `excel` memanggil
/// `ZipDecoder().decodeBuffer` dan `ArchiveFile.compress` yang sudah tidak
/// ada di `archive` 4.x, dan tidak ada versi `excel` yang lebih baru.
/// Implementasi ini hanya memakai `archive` 4.6.0 + `xml` (keduanya sudah
/// menjadi dependensi proyek) dan membaca sheet pertama.
///
/// Yang didukung:
/// - shared strings (`t="s"`), inline strings (`t="inlineStr"`),
///   string hasil formula (`t="str"`), ISO date (`t="d"`), boolean, angka;
/// - tanggal serial Excel (angka + style tanggal di styles.xml) — termasuk
///   kompensasi bug kabisat 1900 Excel;
/// - sel kosong / baris renggang (diisi string kosong).
/// Yang TIDAK didukung: sheet selain yang pertama, sel gabungan (merge),
/// dan nilai error (`t="e"` dibaca sebagai string kosong).
class XlsxReader {
  /// Baca sheet pertama file .xlsx menjadi baris string
  /// (baris pertama = header), seperti [ImportService.parseCsv].
  static List<List<String>> readRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, List<int>>{};
    for (final f in archive.files) {
      if (f.isFile) files[f.name] = f.content as List<int>;
    }
    final sheetPath = _firstSheetPath(files);
    if (sheetPath == null) return [];
    final sheetBytes = files[sheetPath];
    if (sheetBytes == null) return [];
    final sharedStrings = _sharedStrings(files['xl/sharedStrings.xml']);
    final dateStyles = _dateStyleIndexes(files['xl/styles.xml']);
    final doc = XmlDocument.parse(String.fromCharCodes(sheetBytes));
    final rows = <List<String>>[];
    for (final rowEl in doc.findAllElements('row')) {
      final cells = <int, String>{};
      var maxCol = -1;
      for (final c in rowEl.findElements('c')) {
        final ref = c.getAttribute('r') ?? '';
        final col = _columnIndex(ref);
        if (col < 0) continue;
        if (col > maxCol) maxCol = col;
        cells[col] = _cellValue(c, sharedStrings, dateStyles);
      }
      if (maxCol < 0) continue;
      rows.add(
        List<String>.generate(maxCol + 1, (i) => cells[i] ?? ''),
      );
    }
    rows.removeWhere((r) => r.every((c) => c.trim().isEmpty));
    return rows;
  }

  /// Cari jalur sheet pertama: lewat workbook.xml + rels, jatuh ke
  /// `xl/worksheets/sheet*.xml` pertama bila rels tidak ada.
  static String? _firstSheetPath(Map<String, List<int>> files) {
    final workbookBytes = files['xl/workbook.xml'];
    if (workbookBytes != null) {
      try {
        final doc = XmlDocument.parse(String.fromCharCodes(workbookBytes));
        final sheet = doc.findAllElements('sheet').firstOrNull;
        final rid = sheet?.getAttribute(
          'id',
          namespace:
              'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        );
        if (rid != null) {
          final relsBytes = files['xl/_rels/workbook.xml.rels'];
          if (relsBytes != null) {
            final rels = XmlDocument.parse(String.fromCharCodes(relsBytes));
            for (final rel in rels.findAllElements('Relationship')) {
              if (rel.getAttribute('Id') == rid) {
                var target = rel.getAttribute('Target') ?? '';
                if (target.startsWith('/')) target = target.substring(1);
                if (!target.startsWith('xl/')) target = 'xl/$target';
                if (files.containsKey(target)) return target;
              }
            }
          }
        }
      } catch (_) {
        // Jatuh ke fallback di bawah.
      }
    }
    final sheets = files.keys
        .where((n) => n.startsWith('xl/worksheets/sheet'))
        .toList()
      ..sort();
    return sheets.isEmpty ? null : sheets.first;
  }

  /// Daftar shared strings: tiap elemen `si` digabung dari semua `t` di
  /// dalamnya.
  static List<String> _sharedStrings(List<int>? bytes) {
    if (bytes == null) return [];
    try {
      final doc = XmlDocument.parse(String.fromCharCodes(bytes));
      return doc
          .findAllElements('si')
          .map(
            (si) => si
                .findAllElements('t')
                .map((t) => t.innerText)
                .join(),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Index style (atribut `s` sel) yang berformat tanggal.
  /// numFmtId bawaan Excel untuk tanggal: 14-22, 27-36, 45-47, 50, 57;
  /// numFmt kustom dikenali dari formatCode yang mengandung pola tanggal.
  static const _builtinDateFmtIds = <int>{
    14, 15, 16, 17, 18, 19, 20, 21, 22,
    27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
    45, 46, 47, 50, 57,
  };

  static Set<int> _dateStyleIndexes(List<int>? bytes) {
    if (bytes == null) return {};
    try {
      final doc = XmlDocument.parse(String.fromCharCodes(bytes));
      final customDateIds = <int>{};
      for (final fmt in doc.findAllElements('numFmt')) {
        final code = (fmt.getAttribute('formatCode') ?? '').toLowerCase();
        final id = int.tryParse(fmt.getAttribute('numFmtId') ?? '');
        if (id == null) continue;
        // Pola tanggal umum: yyyy/mm/dd (dan variannya).
        if (RegExp(r'y{2,4}|mm|dd').hasMatch(code)) customDateIds.add(id);
      }
      final dateStyles = <int>{};
      final xfs = doc.findAllElements('cellXfs').firstOrNull;
      if (xfs == null) return {};
      var index = 0;
      for (final xf in xfs.findElements('xf')) {
        final fmtId = int.tryParse(xf.getAttribute('numFmtId') ?? '');
        if (fmtId != null &&
            (_builtinDateFmtIds.contains(fmtId) ||
                customDateIds.contains(fmtId))) {
          dateStyles.add(index);
        }
        index++;
      }
      return dateStyles;
    } catch (_) {
      return {};
    }
  }

  static String _cellValue(
    XmlElement c,
    List<String> sharedStrings,
    Set<int> dateStyles,
  ) {
    final type = c.getAttribute('t');
    final style = int.tryParse(c.getAttribute('s') ?? '');
    final v = c.findElements('v').firstOrNull?.innerText;
    switch (type) {
      case 's':
        final idx = int.tryParse(v ?? '');
        if (idx == null || idx < 0 || idx >= sharedStrings.length) return '';
        return sharedStrings[idx];
      case 'inlineStr':
      case 'str':
        final inline = c.findElements('is').firstOrNull;
        if (inline != null) {
          return inline.findAllElements('t').map((t) => t.innerText).join();
        }
        return v ?? '';
      case 'b':
        return v ?? '';
      case 'e':
        return '';
      case 'd':
        return v ?? '';
      default:
        if (v == null || v.isEmpty) return '';
        final num = double.tryParse(v);
        if (num == null) return v;
        if (style != null && dateStyles.contains(style)) {
          return _excelSerialToIso(num);
        }
        // Angka bulat ditulis tanpa ".0" (mis. 7000000, bukan 7000000.0).
        if (num == num.truncateToDouble()) return num.truncate().toString();
        return v;
    }
  }

  /// Serial tanggal Excel -> ISO yyyy-MM-dd.
  /// Excel menghitung hari sejak 1899-12-30, dengan bug: tahun 1900
  /// dianggap kabisat (serial 60 = 29 Feb 1900 yang tidak ada). Untuk
  /// serial > 60, basis 1899-12-30 sudah benar; untuk 1..60, +1 hari.
  static String _excelSerialToIso(double serial) {
    final days = serial.truncate();
    final date = DateTime(1899, 12, 30).add(
      Duration(days: days > 60 ? days : days + 1),
    );
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Index kolom dari referensi sel ("B2" -> 1, "AA3" -> 26).
  static int _columnIndex(String ref) {
    final m = RegExp(r'^([A-Z]+)').firstMatch(ref.toUpperCase());
    if (m == null) return -1;
    var index = 0;
    for (final code in m.group(1)!.codeUnits) {
      index = index * 26 + (code - 0x40);
    }
    return index - 1;
  }
}
