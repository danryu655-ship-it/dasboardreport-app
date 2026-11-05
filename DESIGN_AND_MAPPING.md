# DasboardReport — Pemetaan Web App → Flutter (Fase 1)

Sumber: `~/workspace/dasboardreport-src/index.html` (3091 baris, single-file SPA),
`manifest.json`, `logo.png`, `icon-192x192.png`, `icon-512x512.png`.
Web app v2.9.30 (catatan update menyebut 2.9.31 terbaru). Flutter v1 = **2.9.31+1**.

> **Scope v1 (keputusan pengguna): TANPA API MySQL dan TANPA URL Google Sheets.**
> Tidak ada sinkronisasi server sama sekali: tidak ada pemanggilan API_URL/API_KEY,
> tidak ada pengiriman ke GSHEET_WEBAPP_URL, dan TIDAK ADA field pengaturan untuk
> URL/key tersebut di v1. Semua data 100% lokal (SQLite + shared_preferences).
> Backup di v1 = ekspor file lokal (PDF/Excel, fase berikutnya) — bukan sinkronisasi.
> Di source web, API_URL='INPUT_API_DISINI', API_KEY='NAMA_API_DISINI',
> GSHEET_WEBAPP_URL='API_GSHEETNYA_DISINI' — semuanya PLACEHOLDER, tidak ada
> endpoint asli yang bisa dipakai.

## 1. Model data (localStorage web → SQLite Flutter)

| localStorage web | SQLite Flutter | Isi |
|---|---|---|
| `dasboard_accounts` (JSON array string) | tabel `profiles` (`name` TEXT PK) | Daftar nama profil |
| `dasboard_active_account` (string) | `shared_preferences` key `active_profile` | Profil aktif |
| `dasboard_lang` ('id' \| 'en') | `shared_preferences` key `lang` | Bahasa, default `id` |
| `dataKeuangan_<profil>` (JSON array) | tabel `transactions` (kolom `profile`) | Transaksi |
| `dataTagihan_<profil>` | tabel `bills` (kolom `profile`) | Tagihan |
| `dataPiutangSQL_<profil>` | tabel `debts` (kolom `profile`) | Hutang/piutang (di v1: lokal saja, tanpa sync) |
| `dataLog_<profil>` (maks 50, terbaru dulu) | tabel `activity_logs` (kolom `profile`, maks 50) | Log aktivitas |
| `app_pin_<profil>` (string 4 digit, plain) | `shared_preferences` key `pin_<profil>` | PIN per profil |

### Transaction
`id` (ms epoch), `jenis`: `pemasukan`|`pengeluaran`, `tanggal` (YYYY-MM-DD),
`kategori`, `investasiSub` (`Saham`|`Crypto`|`Deposito`, bila kategori Investasi),
`cryptoToken` (USDT/USDC/BTC/ETH/Lainnya), `metodePembayaran`
(Cash/Transfer Bank/QR/Credit Card/Paylater), `detailBank`, `tujuanBank`
(hanya pengeluaran + Transfer Bank), `keterangan` (merchant), `nominal` (int Rp),
`buktiBase64` (foto bukti, opsional — fase berikutnya, simpan sebagai file lokal).

Kategori pemasukan: Gaji, Bonus, Hasil Usaha, Investasi, Lainnya.
Kategori pengeluaran: Makan & Minum, Transportasi, Tagihan Bulanan, Belanja,
Hiburan, Kesehatan, Lainnya.
Ikon kategori: Makan & Minum=restaurant, Transportasi=directions_car,
Belanja=shopping_bag, Hiburan=movie, Kesehatan=medical_services,
Investasi=trending_up, default=receipt_long. Pemasukan=arrow_downward.

Bank transfer: Danamon, BCA, Mandiri, MNC, SeaBank, BRI, OVO, Dana, GoPay.
Kartu kredit: Mastercard, Visa Card, BCA Card, UnionPay, Amex.
Paylater: Paylater BCA, Kredivo, SPayLater, GoPayLater, Akulaku, Traveloka PayLater.

### Bill (tagihan)
`id`, `nama`, `nominal`, `tanggal` (jatuh tempo), `status` (`belum`|`sudah`).
Bayar tagihan → buat transaksi pengeluaran otomatis
("Bayar Tagihan: <nama>", kategori Tagihan Bulanan, Cash) dan kurangi saldo.

### Debt (hutang/piutang)
`id`, `creator_name`, `partner_name`, `jenis` (`piutang`|`utang`),
`tipe_tempo` (`tanpa_tempo`|`cicilan`), `tenor_bulan`, `cicilan_ke`,
`tanggal`, `nominal`, `keterangan`, `status` (`belum`|`sudah`),
`sync_code` (format `UTG-XXXXXX`, di web untuk sinkronisasi server — **di v1
tidak ada fungsi sinkronisasi; field disimpan lokal saja untuk kompatibilitas
data**), `buktiBase64`.
Selesaikan → buat transaksi otomatis (piutang→pemasukan "Pelunasan Piutang: X",
utang→pengeluaran "Pelunasan Hutang: X"); cicilan: tanya buat cicilan berikutnya
(+1 bulan) bila `cicilan_ke < tenor_bulan`.

### ActivityLog
`waktu` (string lokal `id-ID` medium+short), `deskripsi`. Maks 50 entri.

### Aturan hitung (sama persis dengan web)
- Saldo utama = total pemasukan − total pengeluaran (semua waktu).
- Pemasukan/pengeluaran bulan ini = filter bulan+tahun berjalan.
- Tagihan mendatang = jumlah tagihan status `belum`.
- Piutang aktif (kartu oranye dashboard) = saldo bersih hutang/piutang
  = total piutang `belum` − total hutang `belum`.
- Riwayat dashboard = 5 transaksi terbaru (urut tanggal desc).
- Format Rupiah: `Intl.NumberFormat('id-ID', currency IDR, 0 desimal)` →
  di Flutter pakai `intl` `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)`.
- Format tanggal pendek: `d MMM` locale id-ID (mis. `5 Nov`).

## 2. Inventaris fitur (web → fase)

### Fase 1 (tugas ini)
- Data layer: model + SQLite (`sqflite`) + `shared_preferences`.
- App shell + bottom navigation (Home, Wallet, FAB tambah, Report, More).
- Layar kunci PIN: mode `verify` (saat buka app bila PIN ada) dan `set`
  (kosongkan = hapus PIN; 4 digit = simpan); reset darurat: ketik ulang nama
  profil untuk hapus PIN. Kunci ulang otomatis setelah 5 menit idle (fase 1:
  kunci saat app dibuka + saat kembali dari background; timer idle 5 menit
  diimplementasikan bila memungkinkan).
- Manajemen profil: buat profil pertama (welcome), buat/pindah/ganti-nama profil.
  Ganti nama memindahkan semua data profil lama ke nama baru (transaksi,
  tagihan, PIN, log).
- Dashboard: saldo utama + mode privasi (mata, sembunyikan nominal jadi `•••`),
  4 kartu ringkasan (Pemasukan ungu, Pengeluaran biru, Tagihan Mendatang hijau,
  Piutang Aktif oranye), riwayat transaksi terbaru, profil pill aktif,
  tombol kalender + notifikasi (dot bila ada tagihan belum bayar).
- Bahasa default Indonesia (string id; struktur i18n siap untuk en).

### Fase berikutnya (BUKAN fase 1)
- Catat transaksi lengkap + edit/hapus (form: jenis, tanggal, kategori,
  sub-investasi/crypto, metode + bank asal/tujuan, keterangan, nominal, bukti foto).
- Quick record (FAB) — form yang sama dengan mode cepat.
- Wallet: daftar semua transaksi + pencarian, filter tanggal, filter jenis
  (Semua/Masuk/Keluar/Piutang), navigasi bulan, grafik garis pengeluaran harian.
- Report: donut alokasi pengeluaran per kategori + filter periode (YYYY-MM)
  dan kategori, rincian.
- Tagihan: CRUD + tab Belum/Lunas + bayar (buat transaksi otomatis).
- Hutang/piutang: CRUD + tab Hutang/Piutang + rasio + status + selesai/cicilan.
- Split bill: total ÷ jumlah orang.
- Kalender: pilih tanggal → rekap transaksi hari itu.
- Financial Wrapped: pengeluaran terbesar + total transaksi.
- Ekspor lokal PDF (format neraca) / Excel (CSV) + filter kategori & tanggal.
- Lapor bug (form lokal), Catatan Update (statis), Log Aktivitas (layar).
- OCR struk (Tesseract di web → ML Kit / tesseract di Flutter, butuh riset).
- Pengaturan: bahasa id/en penuh, PIN, profil, ekspor.

## 3. Panduan desain (arahan pengguna — berlaku semua layar)

**Ikuti web app PERSIS, versi mobile, LEBIH ELEGAN.** Polish visual saja,
bukan ubah fitur atau alur.

### Identitas visual (dari `:root` index.html — JANGAN diubah)
- Background: putih `#ffffff` (area konten), abu luar `#f5f5f5`.
- Teks utama: hitam `#000000`; teks muted: `#8e8e93`; abu-abu: `#f2f2f7`.
- Nav gelap: `#1c1c1e`.
- Kategori: ungu `#9b65f7`, biru `#2a94f6`, hijau `#0db35c`, oranye `#f2780c`.
- Bahaya: merah `#ff3b30`.
- Font: **Plus Jakarta Sans** (500/600/700/800) via `google_fonts`.
- Ikon: gaya **Material Symbols Rounded** → di Flutter pakai `Icons.*_rounded`
  / `Icons.*_outlined` yang setara (mis. `home_rounded`, `account_balance_wallet_rounded`,
  `pie_chart_rounded`, `add_rounded`, `receipt_long_rounded`, `handshake_rounded`,
  `safety_divider_rounded`, `auto_awesome_rounded`, `visibility`/`visibility_off`).

### Adaptasi mobile + elegan
- Bottom navigation ala aplikasi mobile (bukan nav web): bar gelap `#1c1c1e`,
  bentuk pil membulat (radius ~36), item aktif ber-background putih transparan
  + label muncul; FAB putih bulat di tengah untuk tambah transaksi.
- Kartu: radius besar **20–24**, shadow lembut, spacing lega dan konsisten.
- Hierarki tipografi rapi: judul tebal (800), nominal besar (saldo 32, extra-bold,
  letter-spacing -1), label kecil muted (11–13, semibold).
- Tombol utama tambah transaksi mudah dijangkau jempol (FAB tengah bawah).
- Transisi antar layar halus (fade/slide).
- Kartu ringkasan 2 kolom ala web (folder card warna + potongan atas putih +
  ikon + label + nominal), dipertahankan persis strukturnya.
- Item transaksi: ikon 44 (radius 14, abu `#f2f2f7`), nama tebal 13,
  kategori muted 11, tanggal muted 10; nominal kanan tebal 13
  (hijau untuk pemasukan dengan tanda `+`, hitam untuk pengeluaran `-`).
- Panel/modal: radius atas 28 (bottom sheet), header + tombol tutup bulat abu.

### Struktur layar (sama seperti web)
Dashboard: header (logo + nama app + profile pill + kalender + notifikasi) →
banner status → saldo utama + mata privasi → action bar (Add/Split/Utang/Wrap) →
"Ringkasan Bulan Ini" + link Analisis → 4 kartu → "Transaksi Terbaru" + Lihat Semua
→ daftar transaksi.
Wallet: kartu profil + saldo, navigasi bulan, "Spent", grafik garis, pencarian,
filter tanggal, chip filter, riwayat transaksi.
Report: "Analisis & Laporan", panel Alokasi (donut + dropdown periode/kategori),
rincian.
More (pengaturan): Bahasa, Lapor Bug, Catatan Update, Log Aktivitas, Pengaturan
PIN, Manajemen Profil, Ekspor PDF, Ekspor Excel, (TIDAK ADA Backup GSheet di v1),
footer versi `DasboardReport v2.9.31`.

## 4. Dependensi fase 1
`google_fonts`, `sqflite`, `path`, `shared_preferences`, `provider`, `intl`.
Tidak ada panggilan network kecuali font via `google_fonts`.
