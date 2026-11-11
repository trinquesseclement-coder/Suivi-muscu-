-- Suivi Muscu — schéma Supabase
-- À coller dans Supabase : SQL Editor > New query > Run. Rejouable sans risque.

-- ---------- Profils (un par compte) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  slot smallint not null default 1 check (slot in (1, 2)),
  updated_at timestamptz not null default now()
);
-- Photo de profil (petite image compressée par l'appli, ~20 Ko)
alter table public.profiles add column if not exists avatar text check (avatar is null or char_length(avatar) < 300000);

-- ---------- Séances (prévues et faites) ----------
create table if not exists public.sessions (
  id uuid primary key,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  created_by uuid not null references public.profiles (id) on delete cascade,
  date date not null,
  status text not null check (status in ('planned', 'done')),
  title text not null default 'Séance',
  group_id uuid,
  deleted boolean not null default false,
  data jsonb not null default '{}'::jsonb,   -- exercices, séries, notes, ressenti
  updated_at timestamptz not null default now()
);
create index if not exists sessions_updated_at_idx on public.sessions (updated_at);
create index if not exists sessions_owner_date_idx on public.sessions (owner_id, date);

-- ---------- Exercices perso / corrections du catalogue (partagés) ----------
create table if not exists public.exercises (
  id text primary key,
  data jsonb not null,
  deleted boolean not null default false,
  updated_by uuid references public.profiles (id) on delete set null default auth.uid(),
  updated_at timestamptz not null default now()
);
create index if not exists exercises_updated_at_idx on public.exercises (updated_at);

-- ---------- updated_at posé par le serveur (sert de curseur de synchro) ----------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before insert or update on public.profiles
  for each row execute function public.touch_updated_at();
drop trigger if exists sessions_touch on public.sessions;
create trigger sessions_touch before insert or update on public.sessions
  for each row execute function public.touch_updated_at();
drop trigger if exists exercises_touch on public.exercises;
create trigger exercises_touch before insert or update on public.exercises
  for each row execute function public.touch_updated_at();

-- ---------- Sécurité (RLS) ----------
-- Tout le monde connecté voit tout (vous êtes deux), chacun n'écrit que chez lui,
-- sauf les séances PRÉVUES : on peut planifier pour l'autre.
alter table public.profiles enable row level security;
alter table public.sessions enable row level security;
alter table public.exercises enable row level security;

drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "sessions_read" on public.sessions;
create policy "sessions_read" on public.sessions for select to authenticated using (true);
drop policy if exists "sessions_insert" on public.sessions;
create policy "sessions_insert" on public.sessions for insert to authenticated
  with check (owner_id = auth.uid() or (created_by = auth.uid() and status = 'planned'));
drop policy if exists "sessions_update" on public.sessions;
create policy "sessions_update" on public.sessions for update to authenticated
  using (owner_id = auth.uid() or (created_by = auth.uid() and status = 'planned'))
  with check (owner_id = auth.uid() or (created_by = auth.uid() and status = 'planned'));
-- Pas de DELETE : l'appli fait des suppressions « douces » (deleted = true) pour la synchro.

drop policy if exists "exercises_read" on public.exercises;
create policy "exercises_read" on public.exercises for select to authenticated using (true);
drop policy if exists "exercises_insert" on public.exercises;
create policy "exercises_insert" on public.exercises for insert to authenticated with check (true);
drop policy if exists "exercises_update" on public.exercises;
create policy "exercises_update" on public.exercises for update to authenticated using (true) with check (true);

-- ---------- Temps réel : voir la séance de l'autre en direct ----------
do $$
begin
  begin
    alter publication supabase_realtime add table public.sessions;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.exercises;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.profiles;
  exception when duplicate_object then null;
  end;
end $$;
