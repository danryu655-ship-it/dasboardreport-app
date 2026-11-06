# DasboardReport Flutter — Catatan Build & Environment (Fase 1)

Status: **2026-11-05 ~10:10 WIB — kode fase 1 SELESAI dan terverifikasi
(`flutter analyze` bersih, `flutter test` lolos). APK debug BELUM bisa di-build
karena blocker sandbox (lihat §3).**

## 1. Environment (persisten di ~/workspace)

| Komponen | Lokasi | Versi |
|---|---|---|
| Flutter SDK (stable) | `~/workspace/flutter` | 3.35.7 |
| JDK | `~/workspace/jdk17` | Corretto 17.0.21 (OpenJDK 17 LTS) |
| Android SDK | `~/workspace/android-sdk` | cmdline-tools 12.0, platform-tools 37.0.2, platforms android-35, build-tools 35.0.0 |
| Gradle | `~/workspace/downloads/gradle-8.12-all.zip` (lokal) | 8.12 |
| Proyek | `~/workspace/dasboardreport-flutter` | package `com.dasboardreport.app`, versi `2.9.31+1` |

## 2. Keanehan environment yang sudah diatasi

- **`/tmp` adalah tmpfs 512MB** — JANGAN pakai untuk unduhan besar; semua unduhan
  ada di `~/workspace/downloads/`.
- **apt macet** (`apt-get update` 6+ menit tanpa progres, daftar paket kosong):
  JDK diambil dari Amazon Corretto via curl, bukan apt.
- **Ekstraksi tar Flutter gagal ownership** — pakai `tar --no-same-owner`.
- **Ekstraksi cmdline-tools via python zipfile menghilangkan bit executable** —
  perlu `chmod -R +x .../cmdline-tools/latest/bin/`.
- **Java tidak bisa HTTPS via proxy egress** (`NoSuchElementException` di
  `HttpURLConnection.doTunneling0`): `sdkmanager` dan Gradle wrapper TIDAK bisa
  mengunduh lewat proxy ini. Solusi: unduh paket SDK/Gradle dengan **curl**
  (curl lewat proxy berfungsi), lalu letakkan manual:
  - SDK: `platform-tools_r37.0.2`, `platform-35_r02`, `build-tools_r35_linux`
    diekstrak ke layout `android-sdk/`; lisensi ditulis manual ke
    `android-sdk/licenses/` (hash standar android-sdk-license).
  - Gradle: `gradle-wrapper.properties` → `distributionUrl=file\:/home/hatch/workspace/downloads/gradle-8.12-all.zip`.
- **Semua egress harus lewat proxy** (`https_proxy` env). Koneksi langsung gagal
  (000). Kredensial proxy ada di env var dan BERPUTAR — jangan pernah menulis
  password proxy ke file; turunkan dari `$https_proxy` via shell expansion
  saat menjalankan build (lihat §4).
- **`flutter doctor`**: Flutter ✓, Android toolchain [!] "license status unknown"
  (karena `sdkmanager --licenses` crash di bug proxy Java di atas — kosmetik
  saja; file lisensi sudah ada). Chrome/Linux toolchain ✗ (tidak relevan),
  Android Studio tidak terinstal (tidak dibutuhkan untuk CLI build).
- **RAM VM ketat** (~7,7GB total, ~1GB available): `android/gradle.properties`
  memakai `org.gradle.jvmargs=-Xmx2G` dan `org.gradle.daemon=false`.

## 3. BLOCKER — APK belum bisa di-build (butuh aksi pengguna)

`flutter build apk --debug` gagal di komunikasi Gradle daemon:
`Could not receive a message from the daemon` →
`Unexpected type tag 109 found` (byte 109 = 'm').

Penyebab terverifikasi (uji Java socket ke server lokal, 2026-11-05 ~10:07):
**semua koneksi TCP mentah dari proses Java dicegat sandbox** dan dijawab:
> "muse: Other TCP connections is turned off for this assistant. To allow it,
> ask the user to open Muse settings -> Permissions -> Direct network
> protocols and switch other_tcp from Deny to Ask."

Gradle daemon berkomunikasi via TCP localhost, jadi build Android tidak bisa
jalan selama `other_tcp = Deny`. Python TCP localhost berfungsi normal —
hanya proses Java yang dicegat. Tidak ada podman/docker di VM ini sebagai
jalan lain.

**Yang harus dilakukan pengguna:** buka Muse Settings → Permissions →
Direct network protocols → ubah `other_tcp` dari **Deny** menjadi **Ask**
(lalu setujui saat build meminta). Setelah itu lanjutkan dengan §4.

> ⚠️ **Jangan salah tempat (2026-11-05 ~17:51):** di halaman Permissions
> ada overview "Connector and Web-access defaults" — itu BUKAN pengaturan
> ini. Yang benar ada di bawah, di **Manage permissions → Direct network
> protocols → baris catch-all "other TCP"**. Mengubah default connector
> atau web-access tidak membuka TCP mentah. Bukti: setelah pengguna
> mengubah *sesuatu* jadi Ask (~17:49), build tetap gagal dengan error
> yang sama, dan uji soket Java→Java menunjukkan koneksi MASIH dicegat —
> client membaca byte 109 ('m', awal pesan blokir "muse: Other TCP
> connections is turned off...") dan server tidak pernah menerima koneksi.
> Jadi sampai baris other TCP di Direct network protocols benar-benar Ask,
> daemon tetap tidak bisa berkomunikasi.
>
> **Update 17:55 — other TCP sudah Ask, TAPI daemon tetap gagal.**
> Pengguna mengaktifkan "Koneksi TCP lainnya" (web Settings → Izin →
> Direct network protocols, toggle biru). Perilaku berubah tapi belum
> berhasil: error Gradle berubah dari "Could not receive a message from
> the daemon" menjadi "The first result from the daemon was empty", dan
> uji soket Java→Java kini: client connect lalu baca EOF (-1), server
> tidak pernah accept. Jadi di mode Ask, koneksi TCP Java tidak lagi
> dijawab pesan 'm', tapi langsung ditutup (EOF) tanpa pernah sampai ke
> server. Kartu approval per-koneksi TIDAK pernah muncul (list_pending
> kosong; yang muncul di history hanya approval untuk perintah exec itu
> sendiri, "Allowed once"). Dugaan: approval per-destinasi tidak berjalan
> untuk koneksi localhost, atau koneksi ditutup sebelum sempat dimintakan
> persetujuan.
>
> **Update 17:59 — --no-daemon TIDAK menghindari daemon (definitif).**
> Gradle 8.12 dengan `--no-daemon` SELALU mem-fork single-use daemon
> ("To honour the JVM settings for this build a single-use Daemon process
> will be forked", dari SingleUseDaemonClient, baris ke-14 log --debug,
> tanpa alasan kompatibilitas apa pun). In-process execution tidak ada di
> Gradle 8.12. Percobaan menyamakan GRADLE_OPTS dengan org.gradle.jvmargs
> (Xms/Xmx/Metaspace/CodeCache + locale, bare -Duser.variant, tanpa
> JAVA_TOOL_OPTIONS) semuanya tetap mem-fork. DEFAULT_JVM_OPTS di
> gradlew kosong. Kesimpulan: **APK TIDAK BISA di-build di VM ini** —
> daemon Gradle butuh TCP Java dan sandbox menutup semua TCP Java (Deny:
> pesan 'm'; Ask: EOF). Jalan keluar: (a) cloud build via GitHub Actions
> (butuh repo + upload file, termasuk biner gradle-wrapper.jar dan ikon),
> atau (b) build di PC pengguna (siapkan ZIP + panduan). Menunggu
> keputusan pengguna.

## 4. Cara melanjutkan build (setelah other_tcp diizinkan)

```bash
export JAVA_HOME=/home/hatch/workspace/jdk17
export ANDROID_HOME=/home/hatch/workspace/android-sdk
export ANDROID_SDK_ROOT=/home/hatch/workspace/android-sdk
export PATH="/home/hatch/workspace/flutter/bin:/home/hatch/workspace/jdk17/bin:$PATH"
# Opsi proxy JVM — diturunkan dari env (password proxy TIDAK tertulis di file):
u="${https_proxy#*://}"; auth="${u%%@*}"; hostport="${u#*@}"
export JAVA_TOOL_OPTIONS="-Dhttp.proxyHost=${hostport%%:*} -Dhttp.proxyPort=${hostport##*:} -Dhttps.proxyHost=${hostport%%:*} -Dhttps.proxyPort=${hostport##*:} -Dhttp.proxyUser=${auth%%:*} -Dhttp.proxyPassword=${auth#*:} -Dhttps.proxyUser=${auth%%:*} -Dhttps.proxyPassword=${auth#*:} -Djdk.http.auth.tunneling.disabledSchemes= -Djdk.http.auth.proxying.disabledSchemes= -Dhttp.nonProxyHosts=localhost|127.0.0.1"
cd ~/workspace/dasboardreport-flutter
flutter build apk --debug
# Hasil: build/app/outputs/flutter-apk/app-debug.apk
```

Catatan: unduhan dependensi Gradle (AGP 8.9.1, Kotlin 2.1.0, dst.) memakai
Apache HttpClient di dalam daemon — kemungkinan besar berfungsi lewat proxy
(setelah other_tcp diizinkan); bila gagal, itu masalah berikutnya untuk
diinvestigasi, bukan blocker saat ini.

## 5. Yang sudah selesai di fase 1

- Pemetaan lengkap web app → `DESIGN_AND_MAPPING.md` (model data, localStorage
  keys, fitur, warna, i18n id/en).
- Scaffold Flutter (Material 3, Plus Jakarta Sans via google_fonts,
  bahasa default Indonesia, package `com.dasboardreport.app`).
- Data layer: `lib/models.dart`, `lib/db.dart` (sqflite: profiles, transactions,
  bills, debts, activity_logs; renameProfile memindahkan semua data),
  `lib/prefs.dart` (shared_preferences), `lib/app_state.dart` (ChangeNotifier,
  PIN verify/set/reset darurat, idle-lock 5 menit, nilai dashboard).
- Layar: `lock_screen.dart` (keypad 4 digit + reset darurat),
  `welcome_screen.dart`, `dashboard_screen.dart` (saldo, pemasukan/pengeluaran
  bulan ini, tagihan mendatang, piutang aktif, riwayat 5 terbaru),
  `profile_screen.dart` (buat/pindah/ganti nama profil),
  `home_shell.dart` (bottom nav dark pill + FAB tengah),
  `more_screen.dart` (pengaturan + log aktivitas + update notes + lapor bug —
  TANPA item GSheet/API, sesuai scope v1),
  `placeholder_screen.dart` (Wallet/Report — fase berikutnya).
- `flutter analyze`: **No issues found.** `flutter test`: **All tests passed.**
- Launcher icon dari `assets/icon-512x512.png` sudah di-generate
  (mipmap-hdpi s.d. xxxhdpi).
- Perbaikan dari hasil test: `ChangeNotifierProvider<AppState>` dipindah ke
  dalam `DasboardReportApp.build()` agar entry point mana pun (app/test)
  selalu punya provider di atas `RootGate`.

## 6. Tertunda untuk fase berikutnya (bukan fase 1)

- Build debug APK (terblokir §3) → lalu AAB + signing release (keystore —
  JANGAN dibuat sebelum diminta).
- Form catat transaksi + edit/hapus; Wallet (riwayat/search/filter/tanggal +
  grafik garis harian); Report (donut alokasi + filter periode/kategori).
- Tagihan CRUD + bayar; hutang/piutang CRUD + pelunasan/cicilan; split bill;
  kalender; Financial Wrapped; ekspor PDF (neraca) / Excel (CSV) lokal;
  lapor bug; OCR struk (perlu riset ML Kit/tesseract).
- Sinkronisasi server TIDAK termasuk v1 (keputusan pengguna): tanpa API MySQL,
  tanpa URL Google Sheets, tanpa field pengaturan untuk itu.

## 7. Fase 2 (2026-11-06) — catatan build

- Arsitektur baru (keputusan user): Supabase untuk semua data cloud +
  Google Sheets backup/export; lokal sqflite tetap primer (offline-first).
  Detail: `docs/supabase-setup.md`, `docs/supabase-schema.sql`,
  `docs/sheets-backup-schema.md`, `docs/sheets-backup-apps-script.gs`.
- Proyek Supabase terverifikasi: `https://nbyhscsladjdmwzaomit.supabase.co`
  (OpenAPI public schema v14.18; skema MASIH KOSONG — SQL belum dijalankan
  user di dashboard SQL editor; GET /rest/v1/transactions → 404).
- Spreadsheet backup SUDAH ADA: "Backup DasboardReport"
  (ID `1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg`); skema + Apps Script
  disesuaikan dengan tab/kolom sheet tersebut (jangan buat spreadsheet baru).
- Dependensi baru: `pdf`, `path_provider`, `share_plus`, `image_picker`,
  `supabase_flutter`. `flutter pub get` OK.
- **Konflik versi (diperbaiki):** `pdf 3.12.0` membatasi `archive <4.1.0`,
  tapi `image 4.11.0` (transitif via pdf) memanggil
  `ZLibDecoder.decodeLazy` yang baru ada di `archive >=4.5.0` → `flutter
  test` gagal compile. `pdf 3.13.x` memperbaiki batas ini tapi butuh Dart
  >=3.12 (Flutter 3.35.7 = Dart 3.9.2, lokal & workflow). Solusi:
  `dependency_overrides: archive: ^4.6.0` di `pubspec.yaml` (dengan
  komentar alasan). Hapus override saat Flutter dinaikkan.
  Setelah override: `archive 4.6.0`, `image 4.11.0`, `pdf 3.12.0`.
- DB v3: `bug_reports` + `sync_queue` (migrasi onUpgrade bertahap).
- `flutter analyze`: **No issues found.** `flutter test`: **17 test lolos**
  (1 smoke + 5 parser struk + 7 config cloud/backup + 4 SafeArea nav).
- Bug nav bar: `home_shell.dart` bottom nav dibungkus `SafeArea`
  (lihat DESIGN_AND_MAPPING §5.4).
- TIDAK dilakukan fase 2: build APK lokal (tetap mustahil di VM — Gradle
  daemon TCP diblokir), push GitHub, keystore, deploy Apps Script, dan
  pembuatan tabel Supabase (butuh SQL editor dashboard oleh user).
- File baru fase 2: `lib/screens/` transaction_form, wallet, report,
  bills, debts, split, calendar, wrapped, export, bug_report,
  ocr_service; `lib/services/export_service.dart`;
  `lib/sync/` supabase_config, sync_service, sheets_backup;
  `docs/` supabase-schema.sql, supabase-setup.md, sheets-backup-schema.md,
  sheets-backup-apps-script.gs; `test/` receipt_parser_test,
  cloud_config_test, safe_area_nav_test.
- Hasil lengkap + langkah user: `PHASE2_RESULT.md`.

## Perubahan 2026-11-06 — hapus dua arah + arsip Sheets + 3 masukan uji HP

- Tombstone `sync_deletes` (Supabase) + `_pullDeletes` di sync service;
  SQLite lokal tetap v3 (tidak ada migrasi lokal). Migrasi:
  `docs/supabase-migration-2026-11-06-sync-deletes.sql` (idempotent).
- Apps Script backup ditulis ulang jadi arsip append-only (`mergeTab`,
  tanpa `clearContents`); perlu deploy ulang + update secret bila URL
  berubah. `docs/sheets-backup-schema.md` § arsip.
- Bug "Selesai" Hutang Piutang: tombol Hapus kini tampil di semua baris
  (paritas web). Bug Simpan tertutup nav bar: SafeArea di 4 bottom sheet
  (utang/piutang, tagihan, detail bulan, tagihan belum bayar).
- Fitur Import Excel: `lib/services/import_service.dart`,
  `lib/services/xlsx_reader.dart`, `lib/screens/import_screen.dart`,
  menu di `more_screen.dart`, string `import_*` di `strings.dart`.
- Dependensi: tambah `file_picker ^11.0.3`, `xml ^6.6.1`,
  `archive ^4.6.0` (langsung, sudah di override); hapus `excel ^4.0.6`
  (tidak kompatibel dengan `archive` 4.x — memanggil API yang sudah
  dihapus; tidak ada versi baru). `flutter pub get` OK.
- `flutter analyze`: **No issues found.** `flutter test`: **72 test lolos**
  (8 lama + 14 sync_delete + 35 import + 5 debt_delete + 5 bottom_sheet
  SafeArea + 5 pre-existing lainnya — rincian di SYNC_DELETE_RESULT.md).
- Pelajaran test (lihat SYNC_DELETE_RESULT.md § pengujian): symlink
  `libsqlite3.so` (di luar `~`, hilang saat VM diganti); DB per file test
  (`testDatabasePath`); `initializeDateFormatting('id_ID')` di tiap file
  widget test; drain loop tap test harus menunggu TILE hilang (bukan
  `state.debts` kosong) + pump 3 detik untuk timer debounce sync 2 detik.
- TIDAK dilakukan: build APK lokal (tetap mustahil di VM), push GitHub,
  keystore, rotasi anon key yang bocor (masih tertunda — lihat
  PHASE2_RESULT.md), deploy Apps Script, dan pembuatan tabel/migrasi
  Supabase (butuh SQL editor dashboard oleh user).
- File baru/berubah: lihat SYNC_DELETE_RESULT.md § file. Hasil lengkap +
  langkah user: `SYNC_DELETE_RESULT.md`.
- Hapus satu seri (keputusan user 2026-11-06 ~08:22): `seriesOf` /
  `debtSeriesOf` / `deleteDebtSeries` di `app_state.dart`,
  tombol "Hapus Seri" + dialog konfirmasi (nama/kode, jumlah baris,
  total nominal) di `debts_screen.dart`, string `debt_delete_series*`,
  `createNextInstallment` mewarisi kode seri (+ backfill induk bila
  kosong). Temuan: syncCode BUKAN identitas seri (kode baru per
  cicilan di web + aplikasi) — kunci seri = profil/pihak/jenis/tenor/
  nominal/keterangan. `flutter analyze` bersih; `flutter test`:
  **83 lolos** (72 + 11 baru di `debt_series_delete_test.dart`).
  `debt_delete_test.dart` diperbarui ke label baru. Rincian:
  `SYNC_DELETE_RESULT.md` §8.
