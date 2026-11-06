# Google Sheets — Backup / Export DasboardReport

> **Sheets HANYA backup/export, BUKAN database live.** Sumber kebenaran tetap
> SQLite lokal (offline-first) + Supabase bila terkonfigurasi.

## Spreadsheet tujuan (SUDAH DIBUAT — jangan buat baru)

- Nama: **Backup DasboardReport**
- ID: `1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg`
- URL: https://docs.google.com/spreadsheets/d/1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg/edit
- 5 tab, header baris 1 sudah dibekukan (frozen). **Jangan ubah nama tab
  atau header tanpa mengubah kode pemetaan di `lib/sync/sheets_backup.dart`
  dan `sheets-backup-apps-script.gs` juga.**

## Tab & kolom (sesuai header baris 1 di Sheet)

| Tab | Kolom (berurutan) |
|---|---|
| `Profil` | id, nama, dibuat_pada |
| `Transaksi` | id, profil, tanggal, jenis, kategori, jumlah_rp, keterangan, dibuat_pada |
| `Tagihan` | id, profil, nama, jumlah_rp, jatuh_tempo, status, dibayar_pada |
| `Utang Piutang` | id, profil, jenis, pihak, jumlah_total_rp, sisa_rp, cicilan_rp, status |
| `Log Aktivitas` | id, profil, waktu, aksi, detail |

## Pemetaan model aplikasi → kolom Sheet

Pemetaan ada di `SheetsBackup.mapProfile/mapTransaction/mapBill/mapDebt/mapLog`
(`lib/sync/sheets_backup.dart`) dan dites di `test/cloud_config_test.dart`.

| Kolom Sheet | Sumber (model lokal) | Catatan |
|---|---|---|
| Profil.id | nomor urut (1, 2, ...) | profil lokal tidak punya id numerik |
| Profil.dibuat_pada | — | tidak tercatat lokal → dikirim kosong |
| Transaksi.jumlah_rp | `nominal` | |
| Transaksi.dibuat_pada | — | tidak tercatat lokal (hanya `tanggal`) → kosong |
| Tagihan.jumlah_rp | `nominal` | |
| Tagihan.jatuh_tempo | `tanggal` | |
| Tagihan.dibayar_pada | — | tidak tercatat lokal (hanya `status`) → kosong |
| Utang Piutang.pihak | `partnerName` | |
| Utang Piutang.jumlah_total_rp | tanpa tempo: `nominal`; cicilan: `nominal × tenorBulan` | tiap baris = satu cicilan |
| Utang Piutang.sisa_rp | total − `nominal` × cicilan yang sudah dibayar | `sudah` + tanpa tempo → 0 |
| Utang Piutang.cicilan_rp | cicilan: `nominal`; tanpa tempo: kosong | |
| Log Aktivitas.aksi | frasa sebelum ':' pertama pada deskripsi (mis. "Mencatat transaksi baru"); bila tidak ada ':' → "Aktivitas" | |
| Log Aktivitas.detail | `deskripsi` lengkap | |

Kolom Sheet yang TIDAK ada padanannya di model lokal (`investasiSub`,
`cryptoToken`, `metodePembayaran`, `detailBank`, `tujuanBank`, `buktiPath`,
`syncCode`, `tipeTempo`, `tenorBulan`, `cicilanKe`, `creatorName`) sengaja
tidak ikut terkirim — skema Sheet mengikuti model data web app yang lebih
ringkas. Bila suatu hari kolom itu dibutuhkan, tambahkan kolom baru di Sheet
DAN di `tabColumns` + fungsi map (jangan ubah nama kolom yang sudah ada).

## Format payload (POST JSON ke Apps Script)

```json
{
  "type": "backup",
  "app": "DasboardReport",
  "version": "2.9.31",
  "profile": "Dan",
  "exportedAt": "2026-11-06T00:00:00.000Z",
  "tabs": {
    "Profil": [ { "id": 1, "nama": "Dan", "dibuat_pada": "" } ],
    "Transaksi": [ { "id": 1762..., "profil": "Dan", "tanggal": "2026-11-06", "jenis": "pengeluaran", "kategori": "Makan & Minum", "jumlah_rp": 50000, "keterangan": "Makan siang", "dibuat_pada": "" } ],
    "Tagihan": [ ... ],
    "Utang Piutang": [ ... ],
    "Log Aktivitas": [ ... ]
  }
}
```

## Setup Apps Script (dilakukan belakangan, manual — TIDAK di-deploy sekarang)

1. Buka spreadsheet **Backup DasboardReport** (URL di atas).
2. **Extensions → Apps Script**, tempel isi `sheets-backup-apps-script.gs`,
   simpan.
3. **Deploy → New deployment → Web app**: Execute as "Me", Who has access
   "Anyone" (atau "Anyone with Google account" bila mau dibatasi).
4. Salin URL Web App → berikan sebagai
   `--dart-define=SHEETS_WEBAPP_URL=<url>` saat build (lihat
   `docs/supabase-setup.md` untuk langkah GitHub Secrets). JANGAN menulis
   URL/key di repo.
5. Uji: tekan Backup di aplikasi (layar Ekspor) → buka spreadsheet → tab
   terisi. Bila muncul error, periksa **Executions** di Apps Script.
   PENTING: versi Apps Script ini adalah versi ARSIP (2026-11-06) —
   bila Web App lama (versi snapshot/clearContents) masih ter-deploy,
   deploy ulang dengan file `.gs` terbaru ini, lalu perbarui secret
   `SHEETS_WEBAPP_URL` bila URL-nya berubah.

## Aturan arsip (sejak 2026-11-06) — TIDAK PERNAH menghapus baris

Setiap backup MENGGABUNGKAN payload ke isi tab yang sudah ada, bukan
menimpa:

- Baris lama yang kuncinya tidak ada di payload: **dipertahankan**.
- Baris yang kuncinya ada di payload: **diperbarui di tempat** (nilai baru
  mengganti nilai lama pada baris yang sama).
- Baris baru: **ditambahkan di akhir** tab.
- Catatan yang sudah dihapus di aplikasi **tetap tersimpan di Sheet**
  sebagai arsip — hapusan di aplikasi tidak menghapus baris Sheet.
- Kolom kunci pencocokan: `nama` untuk tab Profil (id Profil hanya nomor
  urut yang bisa dipakai ulang bila profil dihapus lalu dibuat lagi),
  `id` untuk tab lain. Aturan ini diimplementasikan di
  `sheets-backup-apps-script.gs` (`mergeTab`) dan dicerminkan di aplikasi
  (`SheetsBackup.mergeArchiveRows`, `lib/sync/sheets_backup.dart`) yang
  diuji di `test/sync_delete_test.dart`.
- Respons Web App per tab sekarang `{ kept, updated, added }` (bukan lagi
  jumlah baris tertulis): kept = baris lama yang dipertahankan (termasuk
  yang diperbarui), updated = baris lama yang diganti nilainya, added =
  baris baru.

## Batasan yang disadari

- Arsip hanya menambah/memperbarui, tidak pernah menghapus — Sheet bisa
  tumbuh terus; baris arsip lama tidak dibersihkan otomatis.
- Tidak ada restore otomatis dari Sheet ke aplikasi (satu arah: app → Sheet).
- Foto bukti tidak ikut terkirim (tetap lokal).
- Kolom `dibuat_pada` / `dibayar_pada` dikirim kosong karena aplikasi tidak
  mencatat waktu pembuatan/pembayaran itu (hanya tanggal transaksi/status).
- Backup dari dua perangkat berbeda bisa bertabrakan pada `id` laporan bug
  (AUTOINCREMENT lokal per perangkat) — baris dengan id sama akan saling
  menimpa di tempat, sama seperti sebelum perubahan arsip.
