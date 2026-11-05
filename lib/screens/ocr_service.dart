import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Hasil OCR mentah (teks hasil pengenalan).
class OcrResult {
  final String text;
  const OcrResult(this.text);
}

/// Hasil parsing struk — port `scanStrukAI()` dari web app.
/// Aturan web: nominal (pola "Rp 1.234.567" → baris "TOTAL" → angka ribuan
/// terbesar), tanggal DD/MM/YYYY, DD-MM-YYYY, atau DD.MM.YYYY, bank
/// (BCA/BERHASIL/RRN/REF, Mandiri, BRI, Danamon, SeaBank, GoPay, OVO, Dana),
/// metode (QR/QRIS→QR, TRANSFER/TRF→Transfer Bank, CREDIT CARD/KARTU
/// KREDIT→Credit Card, PAYLATER→Paylater, TUNAI/CASH→Cash; hanya bank
/// ketemu → QR), merchant (baris setelah baris tanggal, bukan
/// "NO. TRANSAKSI"/"TOTAL").
class ParsedReceipt {
  final int? nominal;
  final DateTime? tanggal;
  final String? metode;
  final String? bank;
  final String? keterangan;
  const ParsedReceipt({
    this.nominal,
    this.tanggal,
    this.metode,
    this.bank,
    this.keterangan,
  });
}

ParsedReceipt parseReceiptText(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final upper = text.toUpperCase();

  // --- Tanggal DD/MM/YYYY, DD-MM-YYYY, atau DD.MM.YYYY ---
  DateTime? tanggal;
  int dateLineIndex = -1;
  final dateRe = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})');
  for (var i = 0; i < lines.length; i++) {
    final m = dateRe.firstMatch(lines[i]);
    if (m != null) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) {
        final parsed = DateTime.tryParse(
          '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        );
        if (parsed != null) {
          tanggal = parsed;
          dateLineIndex = i;
          break;
        }
      }
    }
  }

  // --- Bank ---
  String? bank;
  if (upper.contains('BCA') ||
      upper.contains('BERHASIL') ||
      upper.contains('RRN') ||
      upper.contains('REF')) {
    bank = 'BCA';
  } else if (upper.contains('MANDIRI')) {
    bank = 'Mandiri';
  } else if (upper.contains('BRI')) {
    bank = 'BRI';
  } else if (upper.contains('DANAMON')) {
    bank = 'Danamon';
  } else if (upper.contains('SEABANK')) {
    bank = 'SeaBank';
  } else if (upper.contains('GOPAY')) {
    bank = 'GoPay';
  } else if (upper.contains('OVO')) {
    bank = 'OVO';
  } else if (upper.contains('DANA')) {
    bank = 'Dana';
  }

  // --- Metode ---
  String? metode;
  if (upper.contains('QRIS') || upper.contains('QR')) {
    metode = 'QR';
  } else if (upper.contains('TRANSFER') || upper.contains('TRF')) {
    metode = 'Transfer Bank';
  } else if (upper.contains('CREDIT CARD') ||
      upper.contains('KARTU KREDIT')) {
    metode = 'Credit Card';
  } else if (upper.contains('PAYLATER')) {
    metode = 'Paylater';
  } else if (upper.contains('TUNAI') || upper.contains('CASH')) {
    metode = 'Cash';
  } else if (bank != null) {
    metode = 'QR';
  }

  // --- Nominal ---
  int? nominal;
  final rpRe = RegExp(r'Rp\s*([\d.,]+)', caseSensitive: false);
  final rpMatch = rpRe.firstMatch(text);
  if (rpMatch != null) {
    nominal = _parseNumber(rpMatch.group(1)!);
  }
  if (nominal == null) {
    // Baris yang mengandung TOTAL.
    for (final line in lines) {
      if (line.toUpperCase().contains('TOTAL')) {
        nominal = _largestNumberIn(line);
        if (nominal != null) break;
      }
    }
  }
  if (nominal == null) {
    // Angka ribuan terbesar di seluruh teks.
    var best = 0;
    for (final line in lines) {
      final n = _largestNumberIn(line);
      if (n != null && n > best) best = n;
    }
    if (best >= 1000) nominal = best;
  }

  // --- Merchant: baris setelah baris tanggal (bukan NO. TRANSAKSI/TOTAL) ---
  String? keterangan;
  if (dateLineIndex >= 0 && dateLineIndex + 1 < lines.length) {
    final candidate = lines[dateLineIndex + 1];
    final candidateUpper = candidate.toUpperCase();
    if (!dateRe.hasMatch(candidate) &&
        !candidateUpper.contains('NO. TRANSAKSI') &&
        !candidateUpper.contains('TOTAL')) {
      keterangan = candidate;
    }
  }

  return ParsedReceipt(
    nominal: nominal,
    tanggal: tanggal,
    metode: metode,
    bank: bank,
    keterangan: keterangan,
  );
}

int? _parseNumber(String raw) {
  // "1.234.567" / "1,234,567" / "150000" → int.
  final cleaned = raw.replaceAll(RegExp(r'[.,]'), '');
  return int.tryParse(cleaned);
}

int? _largestNumberIn(String line) {
  final matches = RegExp(r'\d[\d.,]*').allMatches(line);
  var best = 0;
  for (final m in matches) {
    final n = _parseNumber(m.group(0)!);
    if (n != null && n > best) best = n;
  }
  return best == 0 ? null : best;
}

/// Layanan OCR struk.
///
/// Mesin: ML Kit Text Recognition v2 (Latin, varian **bundled** —
/// `com.google.mlkit:text-recognition:16.0.1`, model ter-link statis di APK).
/// 100% on-device dan offline sejak install: tanpa unduhan model, tanpa
/// API key, tanpa server, tanpa gambar yang dikirim ke mana pun.
/// `google_mlkit_text_recognition: ^0.16.0` (0.17.x butuh Flutter 3.44+).
/// Permission baru: NOL (galeri memakai system photo picker).
/// Hasil OCR SELALU ditampilkan di form untuk dikoreksi user sebelum disimpan.
class OcrService {
  static bool get isAvailable => true;

  /// Pilih gambar struk dari galeri lalu kenali teksnya.
  /// Mengembalikan null bila pengguna membatalkan pemilihan gambar.
  static Future<OcrResult?> scanFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognized = await recognizer.processImage(inputImage);
      return OcrResult(recognized.text);
    } finally {
      await recognizer.close();
    }
  }
}
