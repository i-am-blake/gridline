-- Gridline shared leaderboard (Supabase)
-- Paste this whole file into Supabase → SQL Editor → New query, then press Run.
-- Players can only read the top scores and submit their own run; they can't edit or delete anyone's rows.

create table if not exists public.scores (
  player     uuid    not null,                       -- a random id each device makes for itself
  world      text    not null check (world in ('sunset', 'city', 'aether')),
  name       text    not null default 'Rider' check (char_length(name) between 1 and 16),
  best       integer not null default 0 check (best between 0 and 50000000),
  level      integer not null default 1 check (level between 1 and 999),
  vehicle    text    check (vehicle in ('bike', 'board', 'buggy')),
  updated_at timestamptz not null default now(),
  primary key (player, world)
);

-- lock the table: nobody reads or writes it directly
alter table public.scores enable row level security;
revoke all on public.scores from anon, authenticated;

-- what the game reads: top scores per map, without the private player ids
create or replace view public.leaderboard as
  select world, name, best, level, vehicle, updated_at
  from public.scores
  where best > 0;
grant select on public.leaderboard to anon, authenticated;

-- what the game calls after a run: keeps each player's best per map
create or replace function public.submit_score(p_player uuid, p_world text, p_name text, p_best integer, p_level integer, p_vehicle text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into scores (player, world, name, best, level, vehicle)
  values (p_player, p_world, left(coalesce(nullif(trim(p_name), ''), 'Rider'), 16), p_best, p_level, p_vehicle)
  on conflict (player, world) do update set
    name       = excluded.name,
    level      = case when excluded.best > scores.best then excluded.level   else scores.level   end,
    vehicle    = case when excluded.best > scores.best then excluded.vehicle else scores.vehicle end,
    best       = greatest(scores.best, excluded.best),
    updated_at = now();
end $$;
revoke all on function public.submit_score(uuid, text, text, integer, integer, text) from public;
grant execute on function public.submit_score(uuid, text, text, integer, integer, text) to anon, authenticated;
