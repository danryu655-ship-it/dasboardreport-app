-- ============================================================
-- DasboardReport — Skema Supabase (Postgres + RLS)
-- Jalankan SEKALI di SQL Editor proyek Supabase (setelah proyek dibuat).
-- JANGAN jalankan dari aplikasi; file ini hanya dokumentasi setup.
-- Proyek (terverifikasi 2026-11-06): https://nbyhscsladjdmwzaomit.supabase.co
-- Status saat file ini ditulis: skema public MASIH KOSONG (GET /rest/v1/
-- hanya mengembalikan 2 path; GET /rest/v1/transactions -> 404).
-- Setelah SQL ini dijalankan, verifikasi dengan:
--   python3 ~/workspace/custom-connectors/custom.supabase/bin/sb_rest.py /rest/v1/
-- (harus muncul path /transactions, /bills, /debts, /profiles, /wallets,
--  /bug_reports) dan GET /rest/v1/transactions?select=*&limit=1 -> [].
-- Prasyarat di dashboard Supabase: aktifkan provider "Anonymous"
-- (Authentication → Sign-in providers → Anonymous) agar aplikasi bisa
-- masuk tanpa login email.
-- ============================================================

-- ---------- Tabel: profil (multi-profil aplikasi) ----------
-- Profil lokal hanya berupa nama (tabel `profiles`, name TEXT PK).
-- Kunci alami di Supabase: (user_id, name).
create table if not exists public.profiles (
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, name)
);

-- ---------- Tabel: transaksi ----------
create table if not exists public.transactions (
  id bigint primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  profile text not null,
  jenis text not null check (jenis in ('pemasukan', 'pengeluaran')),
  tanggal date not null,
  kategori text not null,
  "investasiSub" text not null default '',
  "cryptoToken" text not null default '',
  "metodePembayaran" text not null default 'Cash',
  "detailBank" text not null default '',
  "tujuanBank" text not null default '',
  keterangan text not null,
  nominal bigint not null,
  "buktiPath" text not null default '',
  updated_at timestamptz not null default now()
);

-- ---------- Tabel: tagihan ----------
create table if not exists public.bills (
  id bigint primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  profile text not null,
  nama text not null,
  nominal bigint not null,
  tanggal date not null,
  status text not null default 'belum' check (status in ('belum', 'sudah')),
  updated_at timestamptz not null default now()
);

-- ---------- Tabel: utang / piutang ----------
create table if not exists public.debts (
  id bigint primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  profile text not null,
  "creatorName" text not null default '',
  "partnerName" text not null,
  jenis text not null check (jenis in ('piutang', 'utang')),
  "tipeTempo" text not null default 'tanpa_tempo',
  "tenorBulan" int,
  "cicilanKe" int,
  tanggal date not null,
  nominal bigint not null,
  keterangan text not null default '',
  status text not null default 'belum' check (status in ('belum', 'sudah')),
  "syncCode" text not null default '',
  "buktiPath" text not null default '',
  updated_at timestamptz not null default now()
);

-- ---------- Tabel: laporan bug (hanya naik; tidak di-pull) ----------
create table if not exists public.bug_reports (
  id bigint primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  profile text not null,
  fitur text not null,
  severity text not null,
  judul text not null,
  deskripsi text not null,
  langkah text not null default '',
  waktu text not null,
  "createdAt" bigint not null,
  updated_at timestamptz not null default now()
);

-- ---------- Tabel: dompet / akun (disiapkan untuk fitur mendatang) ----------
-- Web app TIDAK punya CRUD akun dompet (tab Wallet web adalah riwayat +
-- grafik), jadi aplikasi Flutter SAAT INI tidak menulis ke tabel ini.
-- Tabel disediakan agar skema lengkap; aktifkan sinkronisasinya bila fitur
-- akun dompet ditambahkan (tambah 'wallets' ke SyncService.syncTables).
create table if not exists public.wallets (
  id bigint primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  profile text not null,
  name text not null,
  type text not null default 'cash',
  balance bigint not null default 0,
  updated_at timestamptz not null default now()
);

-- ---------- Indeks ----------
create index if not exists idx_profiles_user
  on public.profiles (user_id);
create index if not exists idx_transactions_user_profile
  on public.transactions (user_id, profile, tanggal);
create index if not exists idx_bills_user_profile
  on public.bills (user_id, profile);
create index if not exists idx_debts_user_profile
  on public.debts (user_id, profile);

-- ---------- Row Level Security ----------
-- Setiap pengguna (auth.uid() dari sesi anonim) hanya bisa melihat dan
-- mengubah baris miliknya sendiri. Anon key TIDAK bisa membaca data
-- pengguna lain meskipun tabelnya diketahui.
alter table public.profiles enable row level security;
alter table public.transactions enable row level security;
alter table public.bills enable row level security;
alter table public.debts enable row level security;
alter table public.wallets enable row level security;
alter table public.bug_reports enable row level security;

-- Kebijakan: SELECT / INSERT / UPDATE / DELETE hanya untuk pemilik baris.
-- (Satu blok per tabel; pola sama untuk keenam tabel.)
create policy "own rows select" on public.profiles
  for select using (auth.uid() = user_id);
create policy "own rows insert" on public.profiles
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.profiles
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.profiles
  for delete using (auth.uid() = user_id);

create policy "own rows select" on public.transactions
  for select using (auth.uid() = user_id);
create policy "own rows insert" on public.transactions
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.transactions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.transactions
  for delete using (auth.uid() = user_id);

create policy "own rows select" on public.bills
  for select using (auth.uid() = user_id);
create policy "own rows insert" on public.bills
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.bills
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.bills
  for delete using (auth.uid() = user_id);

create policy "own rows select" on public.debts
  for select using (auth.uid() = user_id);
create policy "own rows insert" on public.debts
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.debts
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.debts
  for delete using (auth.uid() = user_id);

create policy "own rows select" on public.wallets
  for select using (auth.uid() = user_id);
create policy "own rows insert" on public.wallets
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.wallets
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.wallets
  for delete using (auth.uid() = user_id);

create policy "own rows select" on public.bug_reports
  for select using (auth.uid() = user_id);
create policy "own rows insert" on public.bug_reports
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on public.bug_reports
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on public.bug_reports
  for delete using (auth.uid() = user_id);

-- ---------- Catatan ----------
-- * `id` memakai id lokal (ms epoch) agar upsert dari antrean sync cocok
--   dengan baris lokal; `updated_at` dipakai untuk pull incremental.
--   Pengecualian: `profiles` memakai kunci alami (user_id, name) karena
--   profil lokal tidak punya id numerik.
-- * Profil multi-akun aplikasi (mis. "Dan", "Usaha") disimpan sebagai
--   kolom `profile` di tiap tabel — BUKAN akun Supabase terpisah — dan
--   daftar namanya disinkronkan lewat tabel `profiles`.
-- * `wallets` disediakan untuk fitur akun dompet di masa depan; aplikasi
--   saat ini TIDAK menulis/membaca tabel ini (saldo dihitung dari transaksi).
-- * Hapus (delete) hanya disinkronkan naik (push); pull tidak menghapus
--   baris lokal (lihat SyncService._pullChanges).
