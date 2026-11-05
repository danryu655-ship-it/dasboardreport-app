# Supabase — Setup Cloud DasboardReport (Fase 2)

> Status 2026-11-06: koneksi ke proyek **SUDAH AKTIF dan TERVERIFIKASI**
> (GET `/rest/v1/` mengembalikan OpenAPI spec public schema v14.18).
> Skema public **MASIH KOSONG** — belum ada tabel. Ikuti langkah 1–4 di bawah.
> Kredensial (anon key) tersimpan di Secure Vault dan TIDAK bisa dibaca
> kembali — user mengisi GitHub Secrets sendiri dari salinan yang dimilikinya
> (dashboard Supabase → Settings → API → anon public key).

## Proyek

- URL: `https://nbyhscsladjdmwzaomit.supabase.co`
- REST: `https://nbyhscsladjdmwzaomit.supabase.co/rest/v1/`
- Konektor: `custom.supabase` — helper uji
  `~/workspace/custom-connectors/custom.supabase/bin/sb_rest.py`

## Langkah 1 — Buat tabel + RLS (dashboard SQL editor)

REST API tidak bisa DDL, jadi tabel dibuat lewat dashboard:

1. Buka https://supabase.com/dashboard → proyek
   `nbyhscsladjdmwzaomit` → **SQL Editor** → **New query**.
2. Tempel SELURUH isi `docs/supabase-schema.sql` lalu **Run**.
3. Tabel yang dibuat: `profiles`, `transactions`, `bills`, `debts`,
   `wallets` (disiapkan untuk fitur mendatang; aplikasi belum menulis ke
   sini), `bug_reports` — masing-masing dengan RLS aktif + 4 kebijakan
   "own rows" (select/insert/update/delete hanya untuk `auth.uid()` sendiri).

Verifikasi dari terminal (konektor `custom.supabase`):

```text
python3 ~/workspace/custom-connectors/custom.supabase/bin/sb_rest.py /rest/v1/
```

Harus muncul path `/profiles`, `/transactions`, `/bills`, `/debts`,
`/wallets`, `/bug_reports`. Lalu:

```text
python3 ~/workspace/custom-connectors/custom.supabase/bin/sb_rest.py "/rest/v1/transactions?select=*&limit=1"
```

Harus mengembalikan `[]` (bukan 404).

## Langkah 2 — Aktifkan Anonymous Auth

Aplikasi masuk dengan `signInAnonymously()` (satu identitas per instalasi,
tanpa login email) agar RLS bisa mengisolasi data per pengguna:

1. Dashboard → **Authentication** → **Sign-in providers**.
2. Aktifkan **Anonymous** (Anonymous sign-ins → Enable).
3. Bila tidak diaktifkan, aplikasi tetap jalan lokal; status sync di layar
   Lainnya menampilkan "Gagal sinkronisasi".

## Langkah 3 — GitHub Secrets (3 secret, di repo `dasboardreport-app`)

Buka repo GitHub → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Buat tiga secret ini (nama HARUS persis):

| Nama secret | Nilai |
|---|---|
| `SUPABASE_URL` | `https://nbyhscsladjdmwzaomit.supabase.co` |
| `SUPABASE_ANON_KEY` | anon key proyek (dashboard → Settings → API → **anon public** key; JANGAN pakai service_role key) |
| `SHEETS_WEBAPP_URL` | URL Web App Apps Script backup (lihat `docs/sheets-backup-schema.md`; boleh dikosongkan/dilewati bila backup Sheets belum di-deploy — aplikasi tetap jalan, tombol backup menampilkan "belum dikonfigurasi") |

**JANGAN** menulis nilai secret ke file repo, chat, atau issue. Bila secret
bocor, revoke dari dashboard Supabase (Settings → API → Rotate keys).

## Langkah 4 — Workflow build (edit SEKALI, oleh user)

File `.github/workflows/build-apk.yml` **tidak diubah oleh agen** — user yang
mengeditnya setelah secret di langkah 3 terisi. Ganti langkah build yang
sekarang:

```yaml
      - name: Build debug APK
        run: flutter build apk --debug
```

menjadi:

```yaml
      - name: Build debug APK
        run: >
          flutter build apk --debug
          --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}
          --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
          --dart-define=SHEETS_WEBAPP_URL=${{ secrets.SHEETS_WEBAPP_URL }}
```

Bila `SHEETS_WEBAPP_URL` belum ada secret-nya, baris ketiganya boleh
dihapus dulu — build tetap jalan, backup Sheets nonaktif. Tanpa secret
Supabase pun build tetap jalan (aplikasi 100% lokal, sync disabled).

Untuk build lokal (bukan CI), perintah yang sama bisa dijalankan langsung
dengan nilai `--dart-define` diisi manual — JANGAN menuliskannya ke file.

## Cara kerja sync (ringkas)

- Data utama tetap di SQLite lokal (offline-first). Setiap mutasi lokal
  dicatat ke tabel `sync_queue`.
- Bila Supabase terkonfigurasi + online, `SyncService` mendorong antrean
  (upsert/delete) lalu menarik baris yang berubah sejak sync terakhir
  (`updated_at` > `last_sync_at`).
- Auth anonim → `user_id` = `auth.uid()`; RLS memastikan satu instalasi
  tidak bisa membaca data instalasi lain.
- Hapus hanya disinkronkan naik (push); pull tidak menghapus baris lokal.
- Status sync terlihat di layar **Lainnya → Sinkronisasi Cloud** (ketuk
  untuk sync manual; menampilkan jumlah perubahan yang menunggu).
- Laporan bug hanya naik (push) — tidak di-pull, karena id lokalnya
  AUTOINCREMENT dan bisa bertabrakan antar perangkat.
