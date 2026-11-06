# DasboardReport — Hasil Perubahan 2026-11-06: Hapus Dua Arah + Arsip Sheets + 3 Masukan Uji HP

Keputusan user 2026-11-06 ~02:12 WIB: (1) **hapus dua arah untuk data live**
(HP SQLite ↔ Supabase — hapus di mana saja, terhapus di semua tempat live);
(2) **backup Google Sheets jadi arsip sejati — tidak pernah menghapus baris**.
Ditambah 3 masukan dari pengujian APK Fase 2 di HP (2026-11-06 02:18 WIB).

Semua file perubahan sudah disinkronkan ke `~/workspace/dasboardreport-gh/`
(siap upload ke repo). Workflow TIDAK diubah.

---

## 1. Apa yang diubah (file + logika)

### 1.1 Hapus dua arah (live)

| File | Perubahan |
|---|---|
| `lib/sync/sync_service.dart` | Tombstone upsert di cabang delete `_pushQueue`; `_pullDeletes(since)` baru, dipanggil di akhir `_pullChanges`; `buildTombstone()` + `shouldApplyTombstone()` statis (pure, bisa dites); `tombstoneTables` = transaksi/tagihan/utang; komentar atas file diperbarui. |
| `lib/db.dart` | `deleteTransactionIfCreatedBefore` / `deleteBillIfCreatedBefore` / `deleteDebtIfCreatedBefore` (`DELETE ... WHERE id = ? AND id < ?`); `testDatabasePath` statis (override jalur DB hanya untuk test). |
| `docs/supabase-schema.sql` | Tabel `sync_deletes` + unique index + index `(user_id, deleted_at)` + RLS + 4 policy; header + catatan penutup diperbarui. |
| `docs/supabase-migration-2026-11-06-sync-deletes.sql` | **BARU** — migrasi idempotent untuk tabel yang sudah ada (pakai `IF NOT EXISTS`; policy dibuat lewat blok `DO $$ ... IF NOT EXISTS (SELECT 1 FROM pg_policies ...)` karena `CREATE POLICY` tidak punya `IF NOT EXISTS`). |
| `docs/supabase-setup.md` | Langkah 1b baru (jalankan migrasi) + bagian "Cara kerja sync" diperbarui (hapus dua arah + pengecualian profil/bug_reports). |
| `test/sync_delete_test.dart` | **BARU** — 14 test (lihat §4). |

**Skema `public.sync_deletes`:**

```sql
id         bigint generated always as identity primary key
user_id    uuid references auth.users on delete cascade
table_name text
row_id     bigint
row_key    text default ''
deleted_at timestamptz default now()
-- unique index (user_id, table_name, row_id, row_key)  -- upsert idempotent
-- index (user_id, deleted_at)                          -- pull per rentang
-- RLS aktif + 4 policy "own rows" (select/insert/update/delete)
```

SQLite lokal tetap **v3** — tidak ada perubahan skema lokal (tombstone hanya
hidup di server), jadi tidak ada bump versi DB lokal.

### 1.2 Arsip Sheets (append-only)

| File | Perubahan |
|---|---|
| `docs/sheets-backup-apps-script.gs` | Ditulis ulang: `mergeTab` — kunci kolom `nama` (Profil) / `id` (tab lain); baris lama dipertahankan, baris berubah diperbarui di tempat, baris baru ditambah. **Tidak pernah `clearContents`, tidak pernah menghapus baris.** Respons per tab: `{kept, updated, added}`. |
| `lib/sync/sheets_backup.dart` | `archiveKeyColumn` + `mergeArchiveRows({tab, existing, incoming})` (implementasi referensi yang sama dengan Apps Script, dipakai test); komentar kelas diperbarui. |
| `docs/sheets-backup-schema.md` | Bagian "Aturan arsip (sejak 2026-11-06)" + "Batasan" + langkah setup 5 (deploy ulang `.gs` baru; update `SHEETS_WEBAPP_URL` bila URL berubah). |

### 1.3 Bug "Selesai" — Hapus di Hutang Piutang

| File | Perubahan |
|---|---|
| `lib/screens/debts_screen.dart` | Baris aksi tampil bila `!isViewOnly` (status apa pun); Lunasi hanya bila belum lunas; Hapus selalu tampil (lebar penuh bila sudah lunas). |
| `test/debt_delete_test.dart` | **BARU** — 5 test (lihat §4). |

### 1.4 Bug Simpan tertutup navigation bar

| File | Perubahan |
|---|---|
| `lib/screens/debts_screen.dart` | `_showDebtForm` dibungkus `SafeArea(bottom: true, minimum: bottom 12)`. |
| `lib/screens/bills_screen.dart` | `_showBillForm` — pola yang sama. |
| `lib/screens/dashboard_screen.dart` | `_showMonthDetail` + `_showUnpaidBills` — pola yang sama. |
| `test/bottom_sheet_safe_area_test.dart` | **BARU** — 5 test (lihat §4). |

Form transaksi adalah Scaffold layar penuh dengan SafeArea — tidak terdampak.

### 1.5 Fitur baru: Import Excel

| File | Perubahan |
|---|---|
| `lib/services/import_service.dart` | **BARU** — parser CSV RFC 4180, pembaca XLSX, deteksi jenis file, validasi tanggal/nominal, template CSV. |
| `lib/services/xlsx_reader.dart` | **BARU** — pembaca XLSX minimal (sheet pertama) berbasis `archive` + `xml`. |
| `lib/screens/import_screen.dart` | **BARU** — unduh template, pilih file, validasi + pratinjau, impor. |
| `lib/screens/more_screen.dart` | Menu "Import Excel" tepat di bawah "Ekspor Excel". |
| `lib/app_state.dart` | `importTransactions()` / `importDebts()` + `_nextFreshId` (id baru = max(now ms, max id lama)+1; masuk antrean sync). |
| `lib/services/export_service.dart` | Header CSV diekstrak ke konstanta `transactionCsvHeader` / `debtCsvHeader` (satu sumber kebenaran untuk template impor). |
| `lib/strings.dart` | String `import_*` (id + en). |
| `pubspec.yaml` / `pubspec.lock` | Tambah `file_picker ^11.0.3`, `xml ^6.6.1`, `archive ^4.6.0` (langsung); **hapus `excel ^4.0.6`** (lihat §5). |
| `test/import_test.dart` | **BARU** — 35 test (lihat §4). |

### 1.6 Dokumen

- `DESIGN_AND_MAPPING.md` — bagian 6 baru (desain perubahan ini).
- `BUILD_NOTES.md` — bagian perubahan 2026-11-06.
- `PHASE2_RESULT.md` — bagian perubahan 2026-11-06 + langkah user.

---

## 2. Cara kerja hapus dua arah

**Push (hapus di HP → Supabase):** seperti sebelumnya — `deleteTransaction` /
`deleteBill` / `deleteDebt` di `AppState` menghapus baris lokal, lalu
`recordChange` memasukkan entri `delete` ke `sync_queue`. Saat sync, push
menghapus baris di tabel server, lalu **meng-upsert tombstone** ke
`sync_deletes` (`onConflict: 'user_id,table_name,row_id,row_key'`,
`deleted_at` = waktu hapus lokal dari entri antrean). Bila push gagal,
entri antrean dipertahankan untuk retry; kedua sisi idempotent.

**Pull (hapus di Supabase → HP):** setelah loop upsert baris, `_pullDeletes`
menarik tombstone dengan `deleted_at > lastSyncAt`, lalu menghapus baris
lokal yang cocok — **dengan penjaga anti-false-delete**: tombstone hanya
diterapkan bila `rowId < deletedAtMs`. Karena id baris = waktu pembuatan
(ms epoch), baris yang dibuat SETELAH waktu hapusan tidak ikut terhapus,
dan baris yang id-nya SAMA dengan waktu hapusan (ambiguitas 1 ms) juga
dipertahankan. Tombstone tidak pernah di-prune (satu-satunya bukti hapusan).

**Yang TIDAK memakai tombstone (dengan alasan):**

- **Profil** — UI tidak punya hapus profil, hanya rename; rename mencatat
  'delete' nama lama + 'upsert' nama baru, dan pemindahan datanya hanya
  lokal. Menerapkan tombstone nama lama di pull akan membuat data profil
  itu yatim di HP lain.
- **Bug reports** — id-nya AUTOINCREMENT per perangkat, bertabrakan antar
  perangkat; laporan bug memang push-only. Menerapkan hapusannya by id
  bisa menghapus laporan orang lain.
- **Wallet** — tidak disinkronkan.

**Yang TIDAK diuji otomatis:** round-trip tombstone lewat jaringan (butuh
Supabase live). Yang diuji: builder tombstone, penjaga, hapusan lokal
berpenjaga di SQLite, antrean offline, merge arsip (lihat §4). Verifikasi
round-trip dilakukan manual setelah user menjalankan migrasi + rebuild
(lihat §6 langkah 6).

---

## 3. Aturan arsip Sheets

- **Append-only.** Apps Script tidak pernah memanggil `clearContents` dan
  tidak pernah menghapus baris apa pun.
- **Kunci per tab:** `nama` untuk Profil (id-nya hanya nomor urut yang
  dipakai ulang), `id` untuk Transaksi / Tagihan / Utang Piutang / Log
  Aktivitas.
- **Merge per sinkronisasi:** baris lama yang tidak ada di payload tetap
  dipertahankan (`kept`); baris yang kuncinya cocok diperbarui di tempat
  (`updated`); baris baru ditambahkan di akhir (`added`). Header baris 1
  ditulis ulang saja.
- **Konsekuensi yang disengaja:** catatan yang dihapus di aplikasi (dan di
  Supabase) **tetap tersimpan di Sheet sebagai arsip** — Sheet adalah
  riwayat, bukan cermin live. Bila user memang ingin membersihkan arsip,
  hapus barisnya manual di Sheet (tidak ada penghapusan otomatis).
- Respons Apps Script per tab kini `{kept, updated, added}` (aplikasi hanya
  memeriksa status HTTP, jadi aman).

---

## 4. Hasil verifikasi

### `flutter analyze` — **No issues found.**

### `flutter test` — **72 test lolos, 0 gagal** (dijalankan penuh 2026-11-06)

| File test | Jumlah | Isi |
|---|---|---|
| `widget_test.dart` (lama) | 1 | Smoke test aplikasi |
| `cloud_config_test.dart` (lama) | 7 | Konfigurasi cloud + payload backup |
| `receipt_parser_test.dart` (lama) | 5 | Parser struk |
| `safe_area_nav_test.dart` (lama) | 4 | SafeArea pil navigasi |
| `sync_delete_test.dart` | 14 | Builder tombstone (lengkap + pengecualian profil/bug_reports/wallet), penjaga anti-false-delete (sebelum/sesudah/sama), hapusan lokal berpenjaga SQLite (transaksi/utang/tagihan), antrean hapusan offline (entri delete masuk sync_queue + `deleteSyncEntries` menguras antrean), merge arsip (baris lama dipertahankan, update di tempat, tidak pernah lebih pendek, kunci Profil = nama) |
| `import_test.dart` | 35 | Parser CSV (sederhana/CRLF, koma di sel berkutip, kutip ganda, newline di sel, BOM), tanggal (ISO, dd/MM/yyyy, dd-MM-yyyy, tanggal tak ada ditolak, teks sampah ditolak), nominal (polos, ribuan titik, awalan Rp, desimal koma, bukan angka), deteksi jenis header, validasi transaksi (TOTAL dilewati, baris tidak valid ditolak dengan nomor baris, default kategori/metode, header salah/file kosong), validasi utang (status dipertahankan, lunas→sudah, status asing ditolak), template (header == header ekspor, round-trip), XLSX (shared string + angka + tanggal serial, validasi seperti CSV, ekstensi tak didukung ditolak, `.xlsx` dibaca) |
| `debt_delete_test.dart` | 5 | Hapus utang aktif → hilang dari daftar aktif; hapus utang lunas → hilang dari "Selesai" (state); tile lunas menampilkan Hapus (bukan Lunasi); tile aktif menampilkan Lunasi + Hapus; **tap-through**: ketuk Hapus pada tile lunas → dialog konfirmasi → tile hilang dari "Selesai" |
| `bottom_sheet_safe_area_test.dart` | 5 | Form Utang/Piutang 48/24/0, form Tagihan 48/24 — tombol Simpan di atas system bar |
| **Total** | **72** | |

### Verifikasi per item masukan user

1. **Bug "Selesai":** akar masalah terverifikasi di kode + sumber web —
   tombol Hapus memang tidak pernah dibuat untuk baris lunas
   (`!debt.isLunas && !isViewOnly`); `deleteDebt` sendiri berfungsi.
   Setelah perbaikan, 5/5 test lolos termasuk tap-through end-to-end.
   **Keputusan produk ini SUDAH DIPUTUSKAN user 2026-11-06 ~08:22 WIB
   ("hapus satu seri sekaligus") dan diimplementasikan — lihat §8.**
   (Catatan §4 lama bahwa tiap cicilan punya sync_code baru itu benar,
   dan justru itu alasan kode tidak bisa dipakai sebagai kunci seri —
   lihat §8.1.)
2. **Bug Simpan tertutup nav bar:** 4 bottom sheet diperbaiki (utang/
   piutang, tagihan, detail bulan, tagihan belum bayar); 5/5 test lolos
   (posisi tombol Simpan diukur di atas system bar pada padding 48/24/0).
   Form transaksi tidak terdampak (Scaffold layar penuh + SafeArea).
3. **Fitur Import Excel:** menu ada tepat di bawah "Ekspor Excel"; template
   (transaksi + utang/piutang) kolomnya sama persis dengan ekspor (dites
   terhadap konstanta header ekspor + round-trip); 35/35 test lolos
   termasuk XLSX. Impor hanya menambah data baru — data lama tidak pernah
   diubah; baris tidak valid ditolak dengan alasan + nomor baris, baris
   valid lain tetap diimpor.

### Catatan pengujian (untuk pengerjaan berikutnya)

- `sqflite_common_ffi` butuh `libsqlite3.so`; VM hanya punya
  `libsqlite3.so.0` — dibuat symlink
  `/usr/lib/x86_64-linux-gnu/libsqlite3.so -> /lib/x86_64-linux-gnu/libsqlite3.so.0`
  + `ldconfig` (sebagai root). **Di luar `~`, hilang saat VM diganti —
  buat ulang sebelum menjalankan test DB di VM baru.**
- File test DB dipisah per file (`DatabaseHelper.testDatabasePath`) karena
  `flutter test` menjalankan file secara paralel.
- Widget test yang memakai `DateFormat('d MMMM yyyy', 'id_ID')` wajib
  `initializeDateFormatting('id_ID')` di `setUpAll`.
- Tap test: drain loop harus menunggu **tile hilang dari layar** (bukan
  `state.debts` kosong — `_loadProfileData` masih menyelesaikan
  getLogs/getBugReports sesudah debts diisi, dan `notifyListeners` baru
  jalan setelah itu), pakai `pump(Duration)` (pump tanpa durasi tidak
  memajukan animasi pop dialog), lalu `pump(Duration(seconds: 3))` agar
  timer debounce sync 2 detik (dibuat di zona fake-async) selesai —
  kalau tidak, test gagal di teardown ("A Timer is still pending").

---

## 5. Keputusan teknis yang perlu diketahui user

- **Package `excel` 4.0.6 DIHAPUS.** Tidak kompatibel dengan `archive`
  4.6.0 (dipakai `pdf`/`image` — tidak bisa diturunkan): `excel` memanggil
  `ZipDecoder().decodeBuffer` dan `ArchiveFile.compress` yang sudah tidak
  ada di `archive` 4.x, dan tidak ada versi `excel` yang lebih baru
  (4.0.6 = latest). XLSX kini dibaca `lib/services/xlsx_reader.dart`
  (pembaca minimal berbasis `archive` 4.6.0 + `xml`, keduanya sudah
  dependensi proyek): sheet pertama, shared strings, inline strings,
  angka, tanggal serial Excel (termasuk kompensasi bug kabisat 1900).
  Test XLSX membangun file `.xlsx` minimal langsung dari XML + ZIP
  (tanpa package `excel`).
- **`archive` kini dependensi langsung** (`^4.6.0`, juga di
  `dependency_overrides` seperti sebelumnya) dan `xml ^6.6.1` dependensi
  langsung baru. `file_picker ^11.0.3` untuk memilih file (system picker,
  tanpa permission Android baru).
- **Tidak ada perubahan skema lokal** (SQLite tetap v3) dan **tidak ada
  permission Android baru**.

---

## 6. LANGKAH USER (persis, berurutan)

Lakukan SETELAH langkah Fase 2 yang masih tertunda (rotasi anon key yang
bocor — lihat PHASE2_RESULT.md), atau gabungkan dalam satu sesi rebuild.

### Langkah 1 — Jalankan migrasi SQL Supabase (tabel `sync_deletes`)

1. Buka Supabase Dashboard → proyek
   `https://nbyhscsladjdmwzaomit.supabase.co` → **SQL Editor** → **New query**.
2. Salin SELURUH isi file
   `docs/supabase-migration-2026-11-06-sync-deletes.sql` (dari repo, setelah
   upload langkah 3) ke editor, lalu **Run**.
3. Verifikasi: di SQL Editor jalankan
   `select * from public.sync_deletes limit 1;` — harus berhasil dan
   mengembalikan 0 baris (tabel kosong). Atau lewat REST:
   `GET https://nbyhscsladjdmwzaomit.supabase.co/rest/v1/sync_deletes?select=*&limit=1`
   harus mengembalikan `[]`.
4. Bila migrasi dijalankan dua kali tidak apa-apa (idempotent — semua
   memakai `IF NOT EXISTS`).

> Catatan: instalasi baru yang menjalankan `docs/supabase-schema.sql`
> lengkap sudah mendapat tabel ini sekaligus (tidak perlu migrasi).

### Langkah 2 — Deploy ulang Apps Script backup (versi arsip)

1. Buka Sheet **"Backup DasboardReport"** →
   **Extensions → Apps Script**.
2. Ganti SELURUH isi editor dengan file baru
   `docs/sheets-backup-apps-script.gs` (dari repo, setelah upload langkah 3).
3. **Deploy → Manage deployments → Edit (ikon pensil) → Version: New
   version → Deploy.** (Jangan buat deployment baru bila tidak perlu.)
4. Bila URL Web App berubah, catat URL baru dan update GitHub Secret
   `SHEETS_WEBAPP_URL` (lihat langkah 3c). Bila URL sama, tidak ada yang
   perlu diubah.
5. Uji sekali: buka aplikasi → Lainnya → Ekspor & Cadangan Data → jalankan
   backup; buka Sheet — baris lama harus tetap ada, baris baru bertambah
   (respons log Apps Script menunjukkan `{kept, updated, added}` per tab).

### Langkah 3 — Upload kode + rebuild via workflow

1. Salin isi `~/workspace/dasboardreport-gh/` ke repo
   `danryu655-ship-it/dasboardreport-app` (branch `main`) via web UI GitHub
   (upload file) — cara yang sama seperti Fase 1. File `.b64` dan workflow
   di staging JANGAN dihapus/diubah.
2. **PERINGATAN — JANGAN timpa 2 file ini dengan versi lama dari folder
   kerja:** `android/gradle/wrapper/gradle-wrapper.properties` dan
   `android/gradle.properties` di repo SUDAH benar (hasil perbaikan user
   yang membuat build Fase 2 sukses: URL `https://services.gradle.org/...`
   dan `-Xmx4G`). Folder kerja `dasboardreport-flutter/` masih menyimpan
   versi lama yang rusak (`file:` prefix dan `-Xmx2G`) — file itu TIDAK
   ikut disinkronkan ke staging.
3. Perbarui GitHub Secrets bila ada yang berubah (terutama setelah rotasi
   key — lihat PHASE2_RESULT.md): `SUPABASE_URL` =
   `https://nbyhscsladjdmwzaomit.supabase.co` (tanpa `/rest/v1/`),
   `SUPABASE_ANON_KEY` (key baru hasil rotasi),
   `SHEETS_WEBAPP_URL` (URL baru bila berubah di langkah 2).
4. Push ke `main` (atau Run workflow manual) → workflow build APK debug →
   release baru `debug-2.9.31-<run_number>` → install APK di HP seperti
   Fase 2.

### Langkah 4 — Uji di HP (setelah APK baru terinstall)

1. **Hapus dua arah:** hapus satu transaksi di HP → cek di Supabase
   (tabel `transactions` + `sync_deletes` ada barisnya) → hapus satu
   transaksi langsung di Supabase (via Table Editor) → sync di HP (tunggu
   debounce / buka ulang aplikasi) → baris itu hilang dari HP.
2. **Arsip Sheets:** hapus satu transaksi di HP → jalankan backup Sheets →
   baris itu tetap ada di Sheet.
3. **Bug "Selesai":** buat utang/piutang cicilan → lunasi satu cicilan →
   ketuk Hapus pada baris di bagian "Selesai" → baris langsung hilang.
4. **Bug Simpan:** buka "Tambah Utang / Piutang" dan "Tambah Tagihan" →
   tombol Simpan tampil utuh di atas tombol sistem.
5. **Import Excel:** Lainnya → Import Excel → unduh Template Transaksi →
   isi 1–2 baris → pilih file → pratinjau → impor → cek transaksi muncul
   di Dashboard (dan masuk antrean sync bila Supabase aktif).

---

## 7. Yang TIDAK dilakukan (sesuai aturan)

- Build APK lokal (tetap mustahil di VM — Gradle daemon TCP diblokir).
- Push ke GitHub (user upload manual via web UI).
- Keystore / signing release.
- Rotasi anon key Supabase yang bocor + deploy ulang Apps Script lama
  (masih tertunda dari Fase 2 — lakukan bersama langkah 6 di atas).
- Hapus berantai satu seri utang/piutang — **SELESAI 2026-11-06 ~08:22 WIB**
  (keputusan user "hapus satu seri sekaligus") — lihat §8.
- Round-trip tombstone lewat jaringan (butuh Supabase live — verifikasi
  manual di §6 langkah 4).

---

## 8. Perubahan lanjutan 2026-11-06 — Hapus satu seri sekaligus

Keputusan user 2026-11-06 ~08:22 WIB: menekan Hapus pada satu baris
cicilan menghapus **seluruh seri** (semua cicilan dengan kode seri yang
sama), aktif maupun sudah lunas. Seri satu baris berarti hanya baris itu.

### 8.1 Temuan desain: syncCode BUKAN identitas seri

Saat mengerjakan ini ditemukan fakta yang mengubah rancangan: baik web
maupun aplikasi selama ini memberi **kode BARU di tiap cicilan** — web
(`index.html` baris 2256: `sync_code: 'UTG-' + Math.random()...` saat
buat cicilan berikutnya) dan aplikasi (`createNextInstallment` memanggil
`_newSyncCode()`), sementara baris pertama dari form punya
`syncCode: ''`. Jadi pengelompokan berdasarkan kode tidak pernah bisa
menyatukan satu seri (temuan ini membalik catatan §4 item 1 yang
menyatakan tiap cicilan punya sync_code baru — itu benar, dan justru
itu alasan kodenya tidak bisa dipakai sebagai kunci seri).

**Identitas seri yang dipakai** (`AppState.seriesOf`, statis + murni,
bisa dites tanpa AppState): semua cicilan dengan **identitas pinjaman
yang sama** — profil, pihak (`partnerName`), jenis, tenor
(`tenorBulan`), nominal, keterangan, dan `tipeTempo == 'cicilan'`.
Baris tanpa tempo selalu seri berisi dirinya sendiri.

**Batasan yang disengaja:** dua pinjaman cicilan yang identik persis
(orang, jenis, tenor, nominal, dan keterangan sama) dianggap satu seri.
Dialog konfirmasi menampilkan jumlah baris + total nominal sebagai
pengaman terakhir sebelum hapus.

**Kode seri ke depan:** `createNextInstallment` kini MEWARISI syncCode
induk (bukan kode baru); bila induk belum punya kode, satu kode baru
dibuat dan diisi ke induk juga (update + upsert) — supaya satu seri
punya satu kode seperti yang user bayangkan.

### 8.2 Apa yang diubah (file + logika)

| File | Perubahan |
|---|---|
| `lib/app_state.dart` | `seriesOf(all, target)` statis + `debtSeriesOf(debt)`; `deleteDebtSeries(id)` baru (hapus tiap baris lokal + `recordChange` delete per baris → satu tombstone per baris saat push; log sekali; kembalikan jumlah baris); `createNextInstallment` mewarisi kode seri + backfill induk bila kosong. `deleteDebt(id)` lama tetap ada (tidak dipakai layar utang lagi). |
| `lib/screens/debts_screen.dart` | Tombol baris cicilan berlabel **"Hapus Seri"** (tanpa tempo tetap "Hapus"); `_deleteDebt` menghitung seri + total nominal, dialog konfirmasi menampilkan nama/kode seri, jumlah baris, dan total nominal; Batal tidak menghapus apa pun; konfirmasi → `deleteDebtSeries`. |
| `lib/strings.dart` | String baru id + en: `debt_delete_series`, `debt_delete_series_title`, `debt_delete_series_confirm`, `debt_delete_series_log`. |
| `test/debt_series_delete_test.dart` | **BARU** — 11 test (lihat §8.3). |
| `test/debt_delete_test.dart` | Diperbarui: ekspektasi label tombol/dialog lama ("Hapus") → "Hapus Seri" (5 test, isi sama). |
| `DESIGN_AND_MAPPING.md` / `BUILD_NOTES.md` | Bagian perubahan ini. |

### 8.3 Hasil verifikasi

- **`flutter analyze`: No issues found.**
- **`flutter test`: 83 test lolos, 0 gagal** (72 sebelumnya + 11 baru).

| File test | Jumlah | Isi |
|---|---|---|
| `debt_series_delete_test.dart` | 11 | `seriesOf` mengelompokkan 12 cicilan berkode campur (baris pertama `''`, sisanya berkode beda) jadi 1 seri — dari baris lunas maupun aktif; tenor/pihak/jenis berbeda → seri berbeda; tanpa tempo → singleton; `deleteDebtSeries` 12 cicilan → 12 hilang lokal + **12 entri delete terantre** (12 rowId berbeda, satu tombstone per baris saat push); seri 1 baris → hanya baris itu; id tidak ada → 0, tidak ada yang terhapus; `createNextInstallment` mewarisi kode induk; mengisi kode ke induk yang masih kosong (induk + anak berkode sama); tile cicilan berlabel "Hapus Seri" vs tanpa tempo "Hapus"; **tap-through Batal** → dialog menampilkan "2 baris cicilan" + "Rp 10.000.000", tidak ada yang terhapus; **tap-through konfirmasi** → seluruh seri hilang (aktif + lunas) + 2 entri delete terantre |

### 8.4 Uji di HP (setelah rebuild, tambah ke §6 langkah 4)

1. Buat utang/piutang cicilan (mis. 3 cicilan) → lunasi cicilan 1 →
   ketuk **Hapus Seri** pada baris mana pun → dialog menampilkan
   "3 baris cicilan" + total nominal → Batal → tidak ada yang berubah
   → Hapus Seri → Konfirmasi → ketiga baris hilang (aktif + "Selesai").
2. Cek Supabase: tabel `sync_deletes` mendapat 1 tombstone per baris
   seri setelah sync (3 baris untuk contoh di atas).
3. Buat cicilan baru dari seri yang sudah ada → cicilan berikutnya
   menampilkan kode yang sama dengan induknya (bukan kode baru).
