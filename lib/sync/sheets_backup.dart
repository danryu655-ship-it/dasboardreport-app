import 'dart:convert';
import 'dart:io';

import 'supabase_config.dart';

/// Backup ke Google Sheets — BUKAN database live.
///
/// Spreadsheet TUJUAN (sudah dibuat, jangan buat baru):
/// "Backup DasboardReport"
/// https://docs.google.com/spreadsheets/d/1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg/edit
/// (ID: 1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg)
///
/// - Dipicu manual oleh pengguna (tombol backup di layar Ekspor).
/// - Mengirim SATU payload JSON (semua tab sekaligus) ke Web App Apps Script
///   yang URL-nya diisi via `--dart-define=SHEETS_WEBAPP_URL=...`.
/// - Apps Script menulis ulang tiap tab sesuai kolom di bawah (header baris 1
///   sudah dibekukan di Sheet; skrip menulis ulang header + baris).
/// - Bila URL belum dikonfigurasi, [backup] mengembalikan
///   [SheetsBackupResult.notConfigured] dan TIDAK mengirim apa pun.
/// - Tidak ada sinkronisasi dua arah: Sheets hanya menerima salinan data
///   untuk arsip; sumber kebenaran tetap SQLite lokal (+ Supabase bila aktif).
class SheetsBackup {
  static const String sheetId = '1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg';
  static const String sheetUrl =
      'https://docs.google.com/spreadsheets/d/$sheetId/edit';

  /// Kolom tiap tab — SAMA PERSIS dengan header baris 1 di Sheet.
  /// Jangan ubah nama tab/kolom tanpa mengubah Sheet-nya juga.
  static const Map<String, List<String>> tabColumns = {
    'Profil': ['id', 'nama', 'dibuat_pada'],
    'Transaksi': [
      'id',
      'profil',
      'tanggal',
      'jenis',
      'kategori',
      'jumlah_rp',
      'keterangan',
      'dibuat_pada',
    ],
    'Tagihan': [
      'id',
      'profil',
      'nama',
      'jumlah_rp',
      'jatuh_tempo',
      'status',
      'dibayar_pada',
    ],
    'Utang Piutang': [
      'id',
      'profil',
      'jenis',
      'pihak',
      'jumlah_total_rp',
      'sisa_rp',
      'cicilan_rp',
      'status',
    ],
    'Log Aktivitas': ['id', 'profil', 'waktu', 'aksi', 'detail'],
  };

  // ---------- Pemetaan model lokal -> kolom Sheet (murni, bisa dites) ----------

  /// Profil: id = nomor urut (profil lokal tidak punya id numerik);
  /// dibuat_pada tidak tercatat lokal -> kosong.
  static Map<String, dynamic> mapProfile(String name, int index) {
    return {'id': index + 1, 'nama': name, 'dibuat_pada': ''};
  }

  /// Transaksi: jumlah_rp = nominal. dibuat_pada tidak tercatat lokal
  /// (hanya tanggal transaksi) -> kosong.
  static Map<String, dynamic> mapTransaction(Map<String, dynamic> t) {
    return {
      'id': t['id'],
      'profil': t['profile'],
      'tanggal': t['tanggal'],
      'jenis': t['jenis'],
      'kategori': t['kategori'],
      'jumlah_rp': t['nominal'],
      'keterangan': t['keterangan'],
      'dibuat_pada': '',
    };
  }

  /// Tagihan: jumlah_rp = nominal, jatuh_tempo = tanggal tagihan.
  /// dibayar_pada tidak tercatat lokal (hanya status) -> kosong.
  static Map<String, dynamic> mapBill(Map<String, dynamic> b) {
    return {
      'id': b['id'],
      'profil': b['profile'],
      'nama': b['nama'],
      'jumlah_rp': b['nominal'],
      'jatuh_tempo': b['tanggal'],
      'status': b['status'],
      'dibayar_pada': '',
    };
  }

  /// Utang/piutang:
  /// - tanpa_tempo: jumlah_total_rp = nominal; cicilan_rp kosong.
  /// - cicilan: tiap baris adalah SATU cicilan senilai nominal, jadi
  ///   jumlah_total_rp = nominal x tenor; cicilan_rp = nominal.
  /// - sisa_rp = total - nominal x cicilan yang sudah dibayar
  ///   (cicilanKe-1 bila baris ini belum lunas, cicilanKe bila sudah).
  static Map<String, dynamic> mapDebt(Map<String, dynamic> d) {
    final nominal = (d['nominal'] as num?)?.toInt() ?? 0;
    final tenor = (d['tenorBulan'] as num?)?.toInt() ?? 0;
    final ke = (d['cicilanKe'] as num?)?.toInt() ?? 0;
    final isCicilan = d['tipeTempo'] == 'cicilan' && tenor > 0;
    final total = isCicilan ? nominal * tenor : nominal;
    final paidCount = d['status'] == 'sudah' ? ke : ke - 1;
    final paid = isCicilan ? nominal * paidCount.clamp(0, tenor) : 0;
    final sisa = d['status'] == 'sudah' && !isCicilan ? 0 : total - paid;
    return {
      'id': d['id'],
      'profil': d['profile'],
      'jenis': d['jenis'],
      'pihak': d['partnerName'],
      'jumlah_total_rp': total,
      'sisa_rp': sisa < 0 ? 0 : sisa,
      'cicilan_rp': isCicilan ? nominal : '',
      'status': d['status'],
    };
  }

  /// Log aktivitas: aksi = frasa sebelum ':' pertama pada deskripsi
  /// (mis. "Mencatat transaksi baru"), detail = deskripsi lengkap.
  /// Bila tidak ada ':', aksi = 'Aktivitas'.
  static Map<String, dynamic> mapLog(Map<String, dynamic> l) {
    final deskripsi = (l['deskripsi'] as String?) ?? '';
    final colon = deskripsi.indexOf(':');
    final aksi = colon > 0 ? deskripsi.substring(0, colon).trim() : 'Aktivitas';
    return {
      'id': l['id'],
      'profil': l['profile'],
      'waktu': l['waktu'],
      'aksi': aksi,
      'detail': deskripsi,
    };
  }

  /// Bangun payload backup dari data aplikasi (dipakai juga oleh tes).
  /// Baris dipetakan ke kolom Sheet; urutan kolom diatur Apps Script.
  static Map<String, dynamic> buildPayload({
    required String profile,
    required List<String> profiles,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> bills,
    required List<Map<String, dynamic>> debts,
    required List<Map<String, dynamic>> logs,
  }) {
    return {
      'type': 'backup',
      'app': 'DasboardReport',
      'version': '2.9.31',
      'profile': profile,
      'exportedAt': DateTime.now().toIso8601String(),
      'tabs': {
        'Profil': [
          for (var i = 0; i < profiles.length; i++) mapProfile(profiles[i], i),
        ],
        'Transaksi': transactions.map(mapTransaction).toList(),
        'Tagihan': bills.map(mapBill).toList(),
        'Utang Piutang': debts.map(mapDebt).toList(),
        'Log Aktivitas': logs.map(mapLog).toList(),
      },
    };
  }

  /// Kirim payload ke Apps Script. Mengembalikan hasil (sukses/gagal/alasan).
  static Future<SheetsBackupResult> backup(Map<String, dynamic> payload) async {
    if (!CloudConfig.isSheetsConfigured) {
      return SheetsBackupResult.notConfigured;
    }
    HttpClient? client;
    try {
      client = HttpClient();
      final request = await client.postUrl(
        Uri.parse(CloudConfig.sheetsWebAppUrl),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SheetsBackupResult.success;
      }
      return SheetsBackupResult.failed('HTTP ${response.statusCode}');
    } catch (e) {
      return SheetsBackupResult.failed(e.toString());
    } finally {
      client?.close(force: true);
    }
  }
}

class SheetsBackupResult {
  final bool ok;
  final bool isNotConfigured;
  final String message;

  const SheetsBackupResult._(this.ok, this.isNotConfigured, this.message);

  static const SheetsBackupResult success = SheetsBackupResult._(
    true,
    false,
    'Backup terkirim.',
  );

  static const SheetsBackupResult notConfigured = SheetsBackupResult._(
    false,
    true,
    'URL backup Google Sheets belum dikonfigurasi.',
  );

  factory SheetsBackupResult.failed(String reason) =>
      SheetsBackupResult._(false, false, 'Gagal mengirim backup: $reason');
}
