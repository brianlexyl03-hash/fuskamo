-- Original MVP schema, now versioned as migration 001.
create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  name text not null, position text not null, age int not null, country text not null,
  club text, strengths text, video_url text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  jersey_number text, created_at timestamptz default now()
);
create table if not exists scouts (
  id uuid primary key default gen_random_uuid(),
  name text not null, organization text, badge_type text default 'PRO',
  verified boolean default false, created_at timestamptz default now()
);
alter table players enable row level security;
alter table scouts enable row level security;
create policy "Public can view approved players" on players for select using (status = 'approved');
create policy "Anyone can submit a player" on players for insert with check (status = 'pending');
create policy "Public can view verified scouts" on scouts for select using (verified = true);
create index if not exists idx_players_status on players(status);
create index if not exists idx_players_created_at on players(created_at desc);
