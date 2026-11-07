# Test plan: DasboardReport

Build: v2.9.32+1 (QRIS fix) · Date: 2026-11-07 · Env: lokal (`flutter test`, sqflite-ffi) + manual (HP Android, APK debug)

Metode: replica-test — rencana dari alur aplikasi, kasus bernomor (H = happy,
E = edge, N = negatif), otomasi sebisa mungkin, sisanya click-through manual.
Aturan: yang dites adalah aplikasi kita sendiri. Severity bug: S1 = kehilangan
data / lubang keamanan / hitungan uang salah / alur inti terblokir; S2 = fitur
rusak tanpa workaround; S3 = rusak tapi ada workaround, atau terlihat salah;
S4 = kosmetik. Jangan ship dengan S1 terbuka.

Status otomasi saat ini: 85 test, terakhir lolos 85/85 (2026-11-07, sesudah
perbaikan QRIS). File test yang ada: `transaction_form_qr_test.dart` (2),
`sync_delete_test.dart` (14), `debt_series_delete_test.dart` (11),
`debt_delete_test.dart` (6), `import_test.dart` (31), `receipt_parser_test.dart` (5),
`cloud_config_test.dart` (7), `bottom_sheet_safe_area_test.dart` (5),
`safe_area_nav_test.dart` (4), `widget_test.dart` (1).

## F01 — Tambah transaksi

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F01-H1 | tambah transaksi | happy | isi nominal 50000, kategori, metode Cash, simpan | muncul di 5-terbaru dashboard + saldo berubah | belum | |
| F01-H2 | tambah pemasukan | happy | isi pemasukan 1000000, simpan | saldo naik 1000000 | belum | |
| F01-E1 | metode QR | edge: regresi QRIS | pilih metode QR | tidak crash + Bank asal menampilkan daftar bank transfer | ada (qr_test) | lolos |
| F01-E2 | simpan ganda | edge: ketuk Simpan 2x cepat | ketuk Simpan dua kali berurutan | hanya 1 transaksi tersimpan | belum | |
| F01-E3 | nominal besar | edge: nominal 999.999.999.999 | simpan | tersimpan + format tampil benar | belum | |
| F01-E4 | catatan panjang | edge: catatan 60+ karakter | simpan, buka detail | layout tidak rusak | belum | |
| F01-E5 | offline | edge: mode pesawat | simpan transaksi | tersimpan lokal, tersinkron saat online | manual | |
| F01-N1 | tanpa nominal | negatif: simpan tanpa nominal | kosongkan nominal, simpan | error, tidak tersimpan | belum | |

## F02 — Edit / hapus transaksi

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F02-H1 | edit transaksi | happy | ubah nominal 50000 → 75000, simpan | saldo ter-update | belum | |
| F02-H2 | hapus transaksi | happy | hapus 1 transaksi | saldo kembali + terhapus di Supabase (tombstone) | ada (sync_delete) | lolos |
| F02-E1 | hapus lalu sync | edge: hapus di HP, sync | hapus, tunggu sync | tidak muncul lagi di cloud | manual | |

## F03 — Tagihan

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F03-H1 | tambah tagihan | happy | isi tagihan listrik 200000, simpan | muncul di daftar tagihan | belum | |
| F03-H2 | bayar tagihan | happy | bayar tagihan | auto expense "Bayar Tagihan" + status lunas | belum | |
| F03-H3 | hapus tagihan | happy | hapus 1 tagihan | hilang dari daftar | belum | |
| F03-E1 | bayar 2x | edge: ketuk Bayar dua kali | bayar, bayar lagi | tidak ada expense ganda | belum | |

## F04 — Utang / piutang

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F04-H1 | tambah utang cicilan | happy | utang 1200000, tenor 12x, simpan | 12 baris cicilan tercatat | belum | |
| F04-H2 | bayar cicilan | happy | bayar 1 cicilan | sisa berkurang 100000 | belum | |
| F04-H3 | lunasi | happy | lunasi utang | status lunas | belum | |
| F04-H4 | Hapus Seri | happy | hapus 1 baris cicilan → pilih "Hapus Seri" | semua baris seri terhapus, dialog menampilkan jumlah baris + total nominal | ada (series_delete) | lolos |
| F04-E1 | hapus 1 baris | edge: hapus tanpa seri | hapus 1 baris cicilan | hanya baris itu yang hilang | ada (debt_delete) | lolos |

## F05 — Import Excel

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F05-H1 | import transaksi | happy | import .xlsx dari export web | masuk ke profil AKTIF, data lama tetap (append) | ada (import_test) | lolos |
| F05-H2 | import utang | happy | import .xlsx berisi utang | utang masuk ke profil aktif | ada (import_test) | lolos |
| F05-N1 | import PDF | negatif: PDF bukan data | pilih file PDF | ditolak — PDF hanya laporan, bukan data import | belum | |
| F05-N2 | kolom tidak cocok | negatif: header beda | import file dengan header salah | error jelas, tidak ada data rusak | belum | |
| F05-E1 | import 2x | edge: import file yang sama 2x | import, import lagi | append (duplikat dimungkinkan) + jumlah baris terimpor dilaporkan | belum | |

## F06 — Export

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F06-H1 | export Excel | happy | export .xlsx | file berisi transaksi | belum | |
| F06-H2 | export PDF | happy | export PDF | laporan terbaca, angka benar | belum | |
| F06-H3 | export CSV | happy | export CSV | file berisi transaksi | belum | |
| F06-E1 | export kosong | edge: tidak ada data | export saat data kosong | file kosong + pesan, tidak crash | belum | |
| F06-E2 | dialog progres | edge: animasi saat menyiapkan file | ketuk Ekspor PDF/Excel/Backup Sheets | dialog "Menyiapkan…" + spinner muncul, tertutup sebelum share sheet dibuka; tombol Excel menampilkan spinner saat sibuk | belum | |

## F07 — OCR struk

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F07-H1 | struk QRIS | happy | foto struk QRIS | metode terisi 'QR', nominal terisi | ada (receipt_parser) | lolos |
| F07-E1 | foto buram | edge: struk tidak terbaca | foto buram | pesan jelas, form tetap bisa diisi manual | manual | |
| F07-N1 | izin kamera ditolak | negatif: tolak izin | tolak izin kamera | tidak crash, bisa isi manual | manual | |

## F08 — Sync Supabase

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F08-H1 | sync naik | happy | tambah transaksi, tunggu sync | muncul di Supabase (cek REST) | manual | |
| F08-H2 | hapus dua arah | happy | hapus di HP | tombstone sync_deletes → terhapus di cloud | ada (sync_delete) | lolos |
| F08-E1 | hapus dari cloud | edge: hapus di cloud dulu, lalu sync | hapus via REST, sync di HP | terhapus lokal (guard: hanya bila rowId < deletedAtMs) | ada (sync_delete) | lolos |
| F08-E2 | profil lain | edge: data profil A saat profil B aktif | ganti profil | data profil A tidak terlihat | belum | |
| F08-E3 | offline lalu online | edge: mode pesawat → simpan → online | simpan offline, nyalakan data | antre tersinkron (debounce 2 detik) | manual | |
| F08-N1 | key lama mati | negatif: anon key lama | pakai key lama (sudah dirotasi) | sync gagal dengan pesan, tidak crash | ada (cloud_config) | lolos |

## F09 — Backup Google Sheets

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F09-H1 | backup | happy | jalankan backup | tab terisi (archive, mergeTab) | manual | |
| F09-E1 | backup tidak menghapus | edge: backup 2x | backup, backup lagi | data Sheets lama tetap ada | manual | |

## F10 — PIN / kunci

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F10-H1 | buka kunci | happy | masukkan PIN 4 digit benar | masuk ke aplikasi | manual | |
| F10-N1 | PIN salah | negatif: PIN salah | masukkan PIN salah | tetap terkunci, tidak masuk | manual | |
| F10-H2 | set / hapus PIN | happy | set PIN baru; kosongkan = hapus | tersimpan / terhapus (cermin web) | manual | |

## F11 — Split bill

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F11-H1 | hitung split | happy | nominal 100000, 4 orang | tiap orang 25000 | belum | |
| F11-E1 | pembagi 0 | edge: 0 orang | hitung dengan 0 orang | pesan, tidak crash | belum | |

## F12 — Laporan, Wrapped, Kalender

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F12-H1 | laporan bulanan | happy | buka Report | angka sesuai transaksi bulan itu | belum | |
| F12-H2 | Financial Wrapped | happy | buka Wrapped | ringkasan tampil | belum | |
| F12-H3 | kalender | happy | buka Calendar | transaksi tampil per tanggal | belum | |

## F13 — Bug report (di dalam aplikasi)

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F13-H1 | kirim bug report | happy | isi + kirim | tersimpan lokal + muncul di history | belum | |
| F13-H2 | copy-draft | happy | copy draft laporan | teks tersalin | belum | |
| F13-E1 | sync aktif | edge: sync menyala | kirim bug report | ter-push ke Supabase bug_reports | manual | |

## F14 — Dashboard & Wallet

| case | flow | type | steps | expected | auto | result |
| --- | --- | --- | --- | --- | --- | --- |
| F14-H1 | saldo live | happy | tambah transaksi | saldo berubah langsung | belum | |
| F14-H2 | 5 transaksi terbaru | happy | buka dashboard | 5 transaksi terbaru tampil | belum | |
| F14-H3 | activity log | happy | lakukan transaksi | tercatat di activity log | belum | |

## Checklist click-through manual (HP Android, APK debug-2.9.32-21)

- [ ] Install -21, buka aplikasi, PIN berfungsi
- [ ] Input transaksi metode QRIS → tidak crash (retest perbaikan QRIS)
- [ ] Tambah + bayar tagihan → expense "Bayar Tagihan" muncul
- [ ] Import .xlsx dari export web → data masuk profil aktif
- [ ] Export PDF + Excel → file terbuka dan benar
- [ ] Foto struk asli → OCR mengisi form
- [ ] Sync Supabase asli (tambah/edit/hapus) → cek di REST
- [ ] Backup Sheets asli → tab terisi, data lama tetap ada
- [ ] Ganti profil → data profil lain tidak terlihat
- [ ] Mode pesawat → simpan → online → tersinkron

## Catatan teknis test (yang sudah dipelajari)

- Test widget yang menunggu async asli (sqflite-ffi / AppState.init) harus
  dibungkus `tester.runAsync(...)`; pola debt test: `runAsync(() => freshState())`
  + loop `runAsync(Future.delayed(200ms))` + `pump(100ms)`.
- `pumpAndSettle` TIMEOUT kalau ada TextField yang fokus (kursor berkedip).
- Setelah simpan, majukan jam palsu ~3 detik supaya Timer debounce SyncService
  (2 detik) ikut jalan — kalau tidak, "Timer is still pending".
- Test sqflite-ffi butuh `libsqlite3.so` — symlink-nya hilang tiap ganti VM,
  pulihkan dengan `sudo ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0
  /usr/lib/x86_64-linux-gnu/libsqlite3.so && sudo ldconfig`.
- Build APK lokal tidak mungkin di VM (sandbox memblokir TCP dari Java/Gradle)
  — hanya lewat GitHub Actions.

## Perintah

```bash
flutter test            # seluruh suite (terakhir 85/85)
flutter analyze         # No issues
```

## To check (belum dipastikan, bukan bug)

- Perilaku ketuk Simpan 2x (F01-E2) — apakah sudah ada proteksi ganda?
- Perilaku import file yang sama 2x (F05-E1) — duplikat memang dibiarkan?
- Lockout setelah PIN salah berulang (F10-N1) — ada batas percobaan?
