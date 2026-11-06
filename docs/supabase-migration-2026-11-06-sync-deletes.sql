-- ============================================================
-- DasboardReport — Migrasi 2026-11-06: hapus dua arah (tombstone)
-- Jalankan SEKALI di SQL Editor proyek Supabase BILA skema dasar
-- (docs/supabase-schema.sql versi sebelum 2026-11-06) SUDAH dijalankan.
-- Proyek yang baru dibuat dari supabase-schema.sql terbaru TIDAK perlu
-- file ini (tabel sync_deletes sudah ada di sana).
--
-- File ini IDEMPOTENT: aman dijalankan ulang — semua objek memakai
-- IF NOT EXISTS, dan kebijakan memakai blok DO ... IF NOT EXISTS
-- (CREATE POLICY tidak punya IF NOT EXISTS).
--
-- Isi: satu tabel baru `public.sync_deletes` + 2 indeks + RLS + 4 kebijakan
-- "own rows". TIDAK mengubah tabel yang sudah ada dan TIDAK menghapus data.
-- Setelah dijalankan, verifikasi dengan:
--   python3 ~/workspace/custom-connectors/custom.supabase/bin/sb_rest.py /rest/v1/
-- (harus muncul path /sync_deletes) dan:
--   python3 ~/workspace/custom-connectors/custom.supabase/bin/sb_rest.py "/rest/v1/sync_deletes?select=*&limit=1"
-- (harus mengembalikan [] — bukan 404).
-- ============================================================

create table if not exists public.sync_deletes (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  table_name text not null,
  row_id bigint not null,
  row_key text not null default '',
  deleted_at timestamptz not null default now()
);

create unique index if not exists idx_sync_deletes_unique
  on public.sync_deletes (user_id, table_name, row_id, row_key);
create index if not exists idx_sync_deletes_user_deleted
  on public.sync_deletes (user_id, deleted_at);

alter table public.sync_deletes enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'sync_deletes'
      and policyname = 'own rows select'
  ) then
    create policy "own rows select" on public.sync_deletes
      for select using (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'sync_deletes'
      and policyname = 'own rows insert'
  ) then
    create policy "own rows insert" on public.sync_deletes
      for insert with check (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'sync_deletes'
      and policyname = 'own rows update'
  ) then
    create policy "own rows update" on public.sync_deletes
      for update using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'sync_deletes'
      and policyname = 'own rows delete'
  ) then
    create policy "own rows delete" on public.sync_deletes
      for delete using (auth.uid() = user_id);
  end if;
end $$;
