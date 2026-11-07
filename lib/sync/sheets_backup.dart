import 'dart:async';
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
/// - ARSIP (sejak 2026-11-06): Apps Script TIDAK PERNAH menghapus baris.
///   Baris baru ditambahkan di akhir, baris yang sudah ada diperbarui di
///   tempat (cocok kunci), baris lama yang tidak ada di payload tetap
///   tersimpan sebagai arsip — termasuk catatan yang sudah dihapus di
///   aplikasi. Aturan arsip ini diimplementasikan di Apps Script dan
///   dicerminkan sebagai [mergeArchiveRows] di sini (diuji sebagai spek).
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
      'version': '2.9.32',
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

  // ---------- Aturan arsip (append-only) ----------

  /// Kolom kunci tiap tab untuk pencocokan baris di arsip.
  /// Profil dikunci 'nama' (id Profil hanya nomor urut yang bisa dipakai
  /// ulang bila profil dihapus lalu dibuat lagi); tab lain dikunci 'id'
  /// (id numerik unik: ms epoch untuk transaksi/tagihan/utang, AUTOINCREMENT
  /// untuk log — unik dalam satu perangkat).
  static const Map<String, String> archiveKeyColumn = {
    'Profil': 'nama',
    'Transaksi': 'id',
    'Tagihan': 'id',
    'Utang Piutang': 'id',
    'Log Aktivitas': 'id',
  };

  /// Gabungkan baris arsip lama ([existing]) dengan baris baru dari payload
  /// ([incoming]) — implementasi referensi aturan arsip, dicerminkan di
  /// Apps Script (`mergeTab` di sheets-backup-apps-script.gs).
  /// Aturan: TIDAK PERNAH menghapus baris.
  /// - Baris lama yang kuncinya tidak ada di payload: dipertahankan.
  /// - Baris yang kuncinya ada di payload: diperbarui di tempat.
  /// - Baris baru: ditambahkan di akhir, sesuai urutan payload.
  /// Hasil tidak pernah lebih pendek dari [existing].
  static List<Map<String, dynamic>> mergeArchiveRows({
    required String tab,
    required List<Map<String, dynamic>> existing,
    required List<Map<String, dynamic>> incoming,
  }) {
    final keyColumn = archiveKeyColumn[tab] ?? 'id';
    final merged = <Map<String, dynamic>>[
      for (final row in existing) Map<String, dynamic>.from(row),
    ];
    final indexByKey = <String, int>{};
    for (var i = 0; i < merged.length; i++) {
      indexByKey['${merged[i][keyColumn]}'] = i;
    }
    for (final row in incoming) {
      final key = '${row[keyColumn]}';
      final idx = indexByKey[key];
      if (idx != null) {
        merged[idx] = Map<String, dynamic>.from(row);
      } else {
        indexByKey[key] = merged.length;
        merged.add(Map<String, dynamic>.from(row));
      }
    }
    return merged;
  }

  /// POST JSON dengan mengikuti redirect secara manual (POST ulang + body).
  ///
  /// Alasan (laporan user 2026-11-07: backup gagal "HTTP 302"): Google Apps
  /// Script membalas POST ke URL /exec dengan HTTP 302 menuju
  /// script.googleusercontent.com. HttpClient bawaan mengikuti redirect 302
  /// dengan mengubah POST -> GET dan MEMBUANG body, sehingga doPost di Apps
  /// Script tidak pernah menerima payload — dan script ini tidak punya
  /// doGet, jadi permintaan itu gagal. Di sini setiap redirect dijawab
  /// dengan POST ulang berisi body yang sama (maks. [maxRedirects]
  /// lompatan), supaya doPost benar-benar menerima payload.
  /// Mengembalikan status + body mentah dari respons terakhir.
  static Future<({int statusCode, String body})> postJson(
    Uri url,
    String body, {
    int maxRedirects = 5,
  }) async {
    var current = url;
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    HttpClient? client;
    try {
      client = HttpClient();
      for (var hop = 0; hop <= maxRedirects; hop++) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException('backup ke Google Sheets timeout', remaining);
        }
        final request = await client.postUrl(current);
        // Jangan biarkan HttpClient mengikuti redirect sendiri (ia mengubah
        // POST 302 -> GET tanpa body); kita yang POST ulang secara manual.
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.write(body);
        final response = await request.close().timeout(remaining);
        final bytes = await response.fold<List<int>>(
          <int>[],
          (acc, chunk) => acc..addAll(chunk),
        );
        final respBody = utf8.decode(bytes, allowMalformed: true);
        final code = response.statusCode;
        final location =
            response.headers.value(HttpHeaders.locationHeader)?.trim();
        final isRedirect =
            (code == 301 ||
                    code == 302 ||
                    code == 303 ||
                    code == 307 ||
                    code == 308) &&
                location != null &&
                location.isNotEmpty;
        if (!isRedirect || hop == maxRedirects) {
          return (statusCode: code, body: respBody);
        }
        current = current.resolve(location);
      }
      // Tidak terjangkau (loop selalu return), tapi demi analyzer:
      return (statusCode: 302, body: '');
    } finally {
      client?.close(force: true);
    }
  }

  /// Kirim payload ke Apps Script. Mengembalikan hasil (sukses/gagal/alasan).
  /// [urlOverride] hanya untuk tes (URL server lokal); bila null, URL diambil
  /// dari --dart-define SHEETS_WEBAPP_URL.
  static Future<SheetsBackupResult> backup(
    Map<String, dynamic> payload, {
    Uri? urlOverride,
  }) async {
    if (urlOverride == null && !CloudConfig.isSheetsConfigured) {
      return SheetsBackupResult.notConfigured;
    }
    final urlRaw = urlOverride?.toString() ?? CloudConfig.sheetsWebAppUrl;
    final body = jsonEncode(payload);
    try {
      final result = await postJson(Uri.parse(urlRaw), body);
      final code = result.statusCode;
      if (code < 200 || code >= 300) {
        if (code == 301 || code == 302) {
          return SheetsBackupResult.failed(
            'HTTP $code — URL Web App dialihkan (deployment mungkin sudah '
            'tidak aktif atau meminta login). Cek deployment Apps Script.',
          );
        }
        return SheetsBackupResult.failed('HTTP $code');
      }
      // Sukses HTTP saja belum cukup: Apps Script harus menjawab JSON
      // {"ok":true}. Bila jawabannya HTML (mis. halaman login Google),
      // berarti deployment meminta login — bukan payload yang salah.
      try {
        final decoded = jsonDecode(result.body);
        if (decoded is Map && decoded['ok'] == true) {
          return SheetsBackupResult.success;
        }
        final err = decoded is Map ? decoded['error']?.toString() : null;
        return SheetsBackupResult.failed(
          err != null && err.isNotEmpty
              ? 'Apps Script: $err'
              : 'Apps Script menjawab ok=false.',
        );
      } catch (_) {
        final snippet =
            result.body.trim().replaceAll(RegExp(r'\s+'), ' ');
        final shown = snippet.length > 120
            ? '${snippet.substring(0, 120)}…'
            : snippet;
        return SheetsBackupResult.failed(
          'Web App tidak mengembalikan JSON (didapat: '
          '${shown.isEmpty ? 'respons kosong' : shown}). Cek deployment '
          'Apps Script — akses harus "Anyone".',
        );
      }
    } catch (e) {
      return SheetsBackupResult.failed(e.toString());
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
