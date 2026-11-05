# DasboardReport — Hasil Fase 2

**Tanggal:** 2026-11-06 · **Versi aplikasi:** 2.9.31+1 · **Package:** `com.dasboardreport.app`
**Proyek kerja:** `~/workspace/dasboardreport-flutter/` · **Staging GitHub:** `~/workspace/dasboardreport-gh/` (identik, terverifikasi `diff -r`)

## Ringkasan

Semua 12 fitur Fase 2 SELESAI, termasuk Receipt OCR (ML Kit on-device).
Arsitektur berubah sesuai keputusan user 2026-11-06 ~00:05 WIB: **Supabase
untuk semua data cloud + Google Sheets sebagai backup/export** (menggantikan
aturan v1 "100% lokal"). Data tetap lokal dulu (sqflite, offline-first).
Bug bottom nav tertutup system bar SUDAH DIPERBAIKI.

**Verifikasi:** `flutter analyze` → **No issues found.** `flutter test` →
**17 test lolos** (1 smoke + 5 parser struk + 7 config cloud/backup +
4 SafeArea nav).

## Fitur selesai

| # | Fitur | File utama |
|---|---|---|
| 1 | Form tambah/edit/hapus transaksi (jenis, nominal Rp format ribuan, kategori mengikuti jenis, sub-investasi, token crypto, metode + bank asal/tujuan, tanggal, keterangan, bukti foto galeri bila bukan Cash). FAB + & tombol Add membuka form. Saldo & ringkasan bulan langsung berubah. | `lib/screens/transaction_form_screen.dart`, `lib/app_state.dart` (`add/update/deleteTransaction`), `lib/db.dart` (`updateTransaction`) |
| 2 | Daftar 5 transaksi terbaru di dashboard dengan edit (tap) + hapus per item; log aktivitas (maks 50/profil) tercatat | `lib/screens/dashboard_screen.dart`, `lib/widgets.dart` (`TransactionTile.onDelete`) |
| 3 | Wallet lengkap ala web: navigasi bulan, saldo + pengeluaran bulan ini, grafik garis harian (ungu #9b65f7), pencarian, filter tanggal, chip jenis (Semua/Masuk/Keluar/Piutang), daftar gabungan transaksi + utang/piutang, edit/hapus, tombol Selesai per utang | `lib/screens/wallet_screen.dart` |
| 4 | Report lengkap: donut alokasi pengeluaran per kategori + filter periode (YYYY-MM) & kategori; bila satu kategori dipilih, donut menampilkan rincian per keterangan; legenda + rincian transaksi | `lib/screens/report_screen.dart` |
| 5 | Tagihan CRUD + bayar (konfirmasi → pengeluaran otomatis "Bayar Tagihan: \<nama\>", kategori Tagihan Bulanan, Cash, hari ini); penanda terlambat | `lib/screens/bills_screen.dart`, `AppState.payBill` |
| 6 | Utang-piutang CRUD + lunasi/cicilan (lunasi → transaksi otomatis "Pelunasan Piutang/Hutang: X"; bila cicilan & ke < tenor, tanya buat cicilan berikutnya +1 bulan) | `lib/screens/debts_screen.dart`, `AppState.settleDebt/createNextInstallment` |
| 7 | Split bill (kalkulator patungan, tidak disimpan — sesuai web) | `lib/screens/split_screen.dart` |
| 8 | Kalender (grid bulan, titik di hari ada transaksi, tap → rekap + daftar hari itu) | `lib/screens/calendar_screen.dart` |
| 9 | Financial Wrapped (pilih tahun: nama profil, total transaksi, total pemasukan/pengeluaran, kategori terbesar, transaksi terbesar, rincian/bulan) | `lib/screens/wrapped_screen.dart` |
| 10 | Export lokal PDF neraca ("LAPORAN KEUANGAN KELOMPOK" + kotak total) & CSV via share sheet; filter jenis + rentang tanggal (default 1 → hari ini); jenis 'utang' mengekspor daftar utang | `lib/services/export_service.dart`, `lib/screens/export_screen.dart` |
| 11 | Bug report benar-benar berfungsi: tersimpan LOKAL (tabel `bug_reports`, ikut sync Supabase bila aktif) + riwayat dengan tombol salin draf + hapus | `lib/screens/bug_report_screen.dart`, `lib/models.dart` (`BugReport`), `lib/db.dart` (v2) |
| 12 | Receipt OCR — SELESAI (lihat § OCR di bawah) | `lib/screens/ocr_service.dart` |

### Tambahan di luar 12 fitur

- **Perbaikan bug nav bar (laporan user 2026-11-06 00:06 WIB):**
  `home_shell.dart` — `bottomNavigationBar` dibungkus `SafeArea(bottom:
  true, minimum: bottom 8)` + padding bawah 8, sehingga pil navigasi
  selalu tampil utuh di atas system navigation bar Android (3-tombol
  maupun gesture bar). Semua body layar sudah memakai `SafeArea` (status
  bar aman). Dites di `test/safe_area_nav_test.dart` (padding 48/24/0).
- **Arsitektur cloud:** `lib/sync/supabase_config.dart` (baca
  `--dart-define`), `lib/sync/sync_service.dart` (SyncService: init +
  sign-in anonim, antrean `sync_queue`, push upsert/delete, pull
  incremental, status disabled/idle/syncing/synced/error, no-op bila belum
  terkonfigurasi), `lib/sync/sheets_backup.dart` (pemetaan model → kolom
  Sheet + POST Apps Script). DB naik ke **v3** (`bug_reports` + `sync_queue`).
- **Dokumen cloud:** `docs/supabase-schema.sql` (6 tabel + RLS),
  `docs/supabase-setup.md` (langkah SQL, Anonymous Auth, GitHub Secrets,
  snippet workflow), `docs/sheets-backup-schema.md`,
  `docs/sheets-backup-apps-script.gs` (siap-tempel).
- **Helper UI baru** di `lib/widgets.dart`: `watchAppState()`,
  `showAppSnack`, `showAppConfirm`, `AppButton`.
- **String baru** (id + en) di `lib/strings.dart` untuk semua layar fase 2.
- **Test baru:** `test/receipt_parser_test.dart` (5),
  `test/cloud_config_test.dart` (7), `test/safe_area_nav_test.dart` (4).
- `placeholder_screen.dart` DIHAPUS (tidak dipakai lagi — Wallet/Report
  sudah layar asli). `BugReportScreen` lama di `more_screen.dart`
  (hanya log + dialog klaim "terkirim") diganti versi baru yang menyimpan
  lokal + salin draf.
- Layar Lainnya kini menampilkan status **Sinkronisasi Cloud** (ketuk untuk
  sync manual) + jalan pintas Tagihan/Utang/Kalender/Wrapped; item Ekspor
  membuka layar Ekspor (bukan "coming soon").

## Receipt OCR — SELESAI (bukan ditunda)

**Rekomendasi riset:** `google_mlkit_text_recognition ^0.16.0` (ML Kit Text
Recognition v2, Latin, varian **bundled**).

- **Bukti on-device:** plugin memakai
  `com.google.mlkit:text-recognition:16.0.1` (bundled, model ter-link
  statis di APK) — terverifikasi di `android/build.gradle` plugin. Offline
  sejak install: tanpa unduhan model, tanpa API key, tanpa server, tanpa
  gambar dikirim ke mana pun. Tidak bergantung pada Play Services.
- **Kompatibilitas:** 0.16.0 butuh Flutter >=3.32.0 / Dart >=3.8.0 — cocok
  Flutter 3.35.7. Versi 0.17.1 TIDAK dipakai (butuh Flutter 3.44+).
  `google_mlkit_commons` ikut otomatis (transitif, jangan ditambah manual).
- **Permission baru: NOL.** OCR tidak butuh permission; galeri memakai
  system photo picker (tanpa `READ_EXTERNAL_STORAGE`). Kamera tidak dipakai.
- **Alur:** tombol "Scan Struk (OCR)" di form → pilih foto dari galeri →
  `TextRecognizer(script: latin)` → `processImage` → `parseReceiptText()`
  (port `scanStrukAI` web: nominal Rp/TOTAL/angka terbesar; tanggal
  DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY; bank BCA/BERHASIL/RRN/REF, Mandiri,
  BRI, Danamon, SeaBank, GoPay, OVO, Dana; metode QR/QRIS→QR,
  TRANSFER/TRF→Transfer Bank, CREDIT CARD/KARTU KREDIT→Credit Card,
  PAYLATER→Paylater, TUNAI/CASH→Cash, hanya bank→QR; merchant = baris
  setelah baris tanggal, bukan "NO. TRANSAKSI"/"TOTAL") → hasil diisi ke
  form untuk **dikoreksi user sebelum disimpan** (tidak auto-save).
- **Batasan jujur:** akurasi tidak sempurna — struk thermal pudar, foto
  blur/miring, atau font kecil bisa salah baca angka (mis. `1` vs `7`);
  nominal wajib dikonfirmasi user. APK naik ~4 MB per ABI (model Latin).
  ML Kit adalah SDK proprietary Google (bukan open-source).

## Supabase — status & yang harus dilakukan user

- **Koneksi SUDAH AKTIF dan TERVERIFIKASI** (2026-11-06 ~00:24 WIB):
  proyek `https://nbyhscsladjdmwzaomit.supabase.co` (REST `/rest/v1/`,
  OpenAPI public schema v14.18). Kredensial (anon key) tersimpan di Secure
  Vault dan tidak bisa dibaca kembali.
- **Skema public MASIH KOSONG** (GET `/rest/v1/` hanya 2 path;
  GET `/rest/v1/transactions` → 404). SQL sudah disiapkan di
  `docs/supabase-schema.sql` (6 tabel: `profiles`, `transactions`,
  `bills`, `debts`, `wallets` [disiapkan untuk fitur mendatang; aplikasi
  belum menulis ke sini], `bug_reports` + RLS "own rows" per tabel).
- **Langkah user (detail di `docs/supabase-setup.md`):**
  1. Dashboard Supabase → SQL Editor → tempel + Run isi
     `docs/supabase-schema.sql`.
  2. Authentication → Sign-in providers → aktifkan **Anonymous**.
  3. Repo GitHub → Settings → Secrets → buat `SUPABASE_URL`
     (= `https://nbyhscsladjdmwzaomit.supabase.co`), `SUPABASE_ANON_KEY`
     (anon public key dari dashboard Settings → API; JANGAN service_role),
     `SHEETS_WEBAPP_URL` (boleh belakangan).
  4. Edit `.github/workflows/build-apk.yml` (SATU langkah, oleh user —
     agen tidak mengubah workflow): ganti `flutter build apk --debug`
     menjadi build dengan `--dart-define=SUPABASE_URL=${{
     secrets.SUPABASE_URL }} --dart-define=SUPABASE_ANON_KEY=${{
     secrets.SUPABASE_ANON_KEY }} --dart-define=SHEETS_WEBAPP_URL=${{
     secrets.SHEETS_WEBAPP_URL }}`. Tanpa secret pun build tetap jalan
     (aplikasi 100% lokal, sync disabled).
  5. Verifikasi: `sb_rest.py /rest/v1/` harus menampilkan path tabel;
     di aplikasi, layar Lainnya → Sinkronisasi Cloud menampilkan status.

## Google Sheets backup — status & yang harus dilakukan user

- **Spreadsheet SUDAH ADA (jangan buat baru):** "Backup DasboardReport",
  ID `1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg`,
  https://docs.google.com/spreadsheets/d/1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg/edit
- 5 tab (header baris 1, frozen): `Profil` (id, nama, dibuat_pada),
  `Transaksi` (id, profil, tanggal, jenis, kategori, jumlah_rp, keterangan,
  dibuat_pada), `Tagihan` (id, profil, nama, jumlah_rp, jatuh_tempo, status,
  dibayar_pada), `Utang Piutang` (id, profil, jenis, pihak,
  jumlah_total_rp, sisa_rp, cicilan_rp, status), `Log Aktivitas` (id,
  profil, waktu, aksi, detail).
- Skema backup + Apps Script SUDAH DISESUAIKAN dengan sheet ini
  (`docs/sheets-backup-schema.md` + `docs/sheets-backup-apps-script.gs` +
  pemetaan di `lib/sync/sheets_backup.dart`, dites). Aturan pemetaan:
  `jumlah_rp` = nominal; cicilan: total = nominal × tenor, sisa =
  total − nominal × cicilan terbayar; `dibuat_pada`/`dibayar_pada` dikirim
  kosong (tidak tercatat lokal); `aksi` log = frasa sebelum ':' pertama.
- **Deploy TIDAK dilakukan** (butuh akun Google user). Langkah user:
  buka spreadsheet → Extensions → Apps Script → tempel
  `sheets-backup-apps-script.gs` → Deploy → New deployment → Web app
  (Execute as "Me") → salin URL → isi secret `SHEETS_WEBAPP_URL` (lihat
  § Supabase langkah 3–4) → uji tombol Backup di layar Ekspor.

## Dependensi baru

`pdf ^3.11.1`, `path_provider ^2.1.5`, `share_plus ^10.0.0`,
`image_picker ^1.1.2` (ter-resolve 1.2.2 — masih kompatibel Flutter 3.35.7),
`supabase_flutter ^2.9.0`, `google_mlkit_text_recognition ^0.16.0`.
Semua gratis, tanpa API key/server.

**Catatan konflik versi (diperbaiki):** `pdf 3.12.0` membatasi
`archive <4.1.0`, tapi `image 4.11.0` (transitif via pdf) memanggil
`ZLibDecoder.decodeLazy` yang baru ada di `archive >=4.5.0` → `flutter
test` gagal compile. `pdf 3.13.x` memperbaiki batas ini tapi butuh Dart
>=3.12 (Flutter 3.35.7 = Dart 3.9.2, lokal & workflow). Solusi:
`dependency_overrides: archive: ^4.6.0` di `pubspec.yaml` (dengan komentar
alasan). Hapus override saat Flutter dinaikkan. Setelah override:
`archive 4.6.0`, `image 4.11.0`, `pdf 3.12.0`.

**Permission Android baru: NOL.** (INTERNET sudah ada dari v1.)

## Yang TIDAK dilakukan (sesuai aturan)

- Build APK lokal (tetap mustahil di VM — Gradle daemon TCP diblokir).
- Push ke GitHub (user upload manual via web UI seperti fase 1).
- Keystore / signing release.
- Deploy Apps Script (butuh akun Google user).
- Pembuatan tabel Supabase (butuh SQL editor dashboard oleh user).
- Pengiriman kredensial apa pun di kode (tidak ada URL/key di repo;
  semua via `--dart-define` + GitHub Secrets).

## Langkah berikutnya untuk user

1. **Masukkan kode ke repo:** salin isi `~/workspace/dasboardreport-gh/`
   ke repo `danryu655-ship-it/dasboardreport-app` (branch `main`) via web
   UI GitHub (upload file) — file `.b64` dan workflow di staging JANGAN
   dihapus/diubah (kecuali langkah workflow di § Supabase langkah 4).
   Cara yang sama seperti fase 1.
2. **Jalankan SQL Supabase** (§ Supabase langkah 1–2).
3. **Isi 3 GitHub Secrets** (§ Supabase langkah 3) + **edit satu langkah
   workflow** (§ Supabase langkah 4).
4. **Deploy Apps Script backup** (§ Sheets) bila mau backup Sheets aktif.
5. **Build ulang via workflow:** push ke `main` (atau Run workflow
   manual) → workflow build APK debug → release baru
   `debug-2.9.31-<run_number>` → install APK di HP/BlueStacks seperti
   fase 1 (APK ~142 MB + ~4 MB model OCR per ABI).
6. **Uji di perangkat:** form transaksi (tambah/edit/hapus, bukti foto,
   scan struk), Wallet (grafik + filter), Report (donut), bayar tagihan,
   lunasi utang/cicilan, kalender, Wrapped, export PDF/CSV, lapor bug,
   dan pastikan pil navigasi bawah tampil utuh (tidak tertutup tombol
   sistem). Bila sync aktif, cek layar Lainnya → Sinkronisasi Cloud.
