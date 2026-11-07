# Ekspor Gabung + Backup Sheets 302 + Filter Piutang — Hasil 2026-11-07

Paket perbaikan berdasarkan 3 laporan user 2026-11-07 malam (semua diuji:
`flutter analyze` bersih, **92/92 tes lolos**).

## 1. Ekspor PDF/Excel jadi 1 (laporan user 19:26)
- Menu Lainnya: 2 item "Ekspor PDF" + "Ekspor Excel" -> **1 item "Ekspor Data"**
  (`lib/screens/more_screen.dart`).
- Layar Ekspor: 2 tombol -> **1 tombol "Ekspor Data"** yang membuka dialog
  pilih format (PDF = laporan neraca, Excel = CSV). Logika ekspor tidak
  berubah (`lib/screens/export_screen.dart`).
- String baru: `export_data`, `export_choose_format`,
  `export_format_pdf_hint`, `export_format_excel_hint` (id + en).

## 2. Ekspor "diam" (laporan user 19:26)
- Penyebab paling mungkin: periode yang dipilih tidak ada datanya, dan
  aplikasi hanya menampilkan snackbar singkat yang mudah terlewat.
- Perbaikan: bila tidak ada data, tampil **dialog "Tidak ada data" yang
  menyebut periode yang dicek** ("...pada periode 1 Nov 2026 – 7 Nov 2026.
  Coba ubah rentang tanggal atau jenis laporan.") — bukan lagi snackbar.
- Versi tampil di footer dinaikkan `v2.9.31` -> **`v2.9.32`** (id + en) dan
  `buildPayload.version` ikut `2.9.32`, supaya build yang terpasang bisa
  dibedakan dari screenshot berikutnya. (Catatan: footer selama ini
  hardcoded di `strings.dart`, bukan dibaca dari pubspec — itulah kenapa
  build -22 kemarin masih menampilkan v2.9.31.)

## 3. Backup Sheets error HTTP 302 (laporan user 19:28)
- Akar masalah: Google Apps Script membalas POST ke URL `/exec` dengan
  HTTP 302 menuju `script.googleusercontent.com`. `HttpClient` bawaan
  mengikuti redirect 302 dengan mengubah POST -> GET dan **membuang body**,
  sehingga `doPost` tidak pernah menerima payload — dan script ini tidak
  punya `doGet`, jadi permintaan gagal. Aplikasi lalu menampilkan mentah
  "HTTP 302".
- Perbaikan (`lib/sync/sheets_backup.dart`): `postJson()` mengikuti
  redirect **secara manual dengan POST ulang + body yang sama** (maks. 5
  lompatan, batas total 45 detik). `backup()` kini juga memvalidasi jawaban:
  harus JSON `{"ok":true}`; bila jawabannya HTML (mis. halaman login
  Google) pesannya jelas ("Web App tidak mengembalikan JSON... cek
  deployment Apps Script — akses harus 'Anyone'"), bukan lagi kode mentah.
- Catatan: perbaikan ini mengatasi sisi aplikasi. Bila deployment Apps
  Script di Google sudah tidak aktif / URL di Secret sudah kedaluwarsa,
  backup tetap gagal — pesannya sekarang akan menjelaskannya.

## 4. Filter Piutang Wallet eksklusif (laporan user 19:34)
- Bug ganda: (a) saat chip Piutang aktif, `WalletScreen` memuat **SEMUA**
  transaksi (`jenis: 'semua'`); (b) `walletDebts(jenis: 'piutang')`
  **mengabaikan parameter jenis** sehingga ikut menampilkan utang. Karena
  itu daftar menampilkan belanja seperti "Beli Celana" padahal filter
  Piutang aktif (sesuai screenshot user).
- Perbaikan: `walletDebts()` kini benar-benar memfilter berdasarkan jenis
  (`lib/app_state.dart`); mode Piutang tidak lagi memuat transaksi sama
  sekali (`lib/screens/wallet_screen.dart`). Saat filter Piutang aktif,
  muncul kartu rekap **"Total Piutang Belum Lunas"** + **"Catatan Belum
  Lunas"** di atas daftar.
- Tes widget `wallet_piutang_filter_test.dart` memakai pola
  `tester.runAsync` (wajib di testWidgets untuk I/O asli; tanpa itu await
  di zona FakeAsync tidak pernah selesai — pelajaran dari debugging tes ini).

## Tes baru (total 92/92 lolos)
- `test/sheets_backup_redirect_test.dart` — server lokal: 302 -> body ikut
  ter-POST ulang; `backup()` sukses setelah redirect; jawaban HTML
  dilaporkan jelas; redirect berantai berhenti setelah batas.
- `test/export_strings_test.dart` — kunci ekspor gabung + versi tampil ada
  di id dan en.
- `test/wallet_piutang_filter_test.dart` — chip Piutang eksklusif (widget)
  + `walletDebts` memfilter jenis (unit).
- `test-plan.md`: kasus baru F06-E3, F06-E4, F09-E2, F14-P1; checklist
  manual diperbarui ke APK debug-2.9.32-23.

## Cara pakai (langkah user)
1. Extract ZIP ini, upload semua file ke repo `dasboardreport-app` via
   GitHub web UI (timpa file lama). **Jangan lupa file workflow**
   `.github/workflows/build-apk.yml` kali ini — kemarin file ini tidak
   ter-upload sehingga nama release masih `debug-2.9.31-22` (isinya sudah
   2.9.32, hanya namanya yang ketinggalan).
2. Actions build -> release **`debug-2.9.32-23`** -> install APK.
3. Cek: footer menampilkan **v2.9.32**; menu Lainnya hanya ada 1 "Ekspor
   Data"; ekspor periode kosong menampilkan dialog periode; chip Piutang
   hanya menampilkan piutang + kartu rekap; Backup Sheets tanpa HTTP 302.
