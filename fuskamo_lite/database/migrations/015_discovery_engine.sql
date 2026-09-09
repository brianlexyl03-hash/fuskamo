-- Backs the Scout–Player Discovery & Ranking Engine
-- (backend/src/services/discoveryEngine.js). Adds the preference/attribute
-- columns the scorer reads, plus an append-only engagement event log used
-- to derive 7-day view/save/contact/share counts and a fraud signal
-- without trusting any client-supplied count directly.

-- ── Scout preferences ──
-- All nullable/empty-array = "no stated preference" and is treated
-- permissively by discoveryEngine.js (never excludes a player, only adds
-- points on an actual match).
alter table scouts add column if not exists preferred_positions text[];
alter table scouts add column if not exists preferred_countries text[];
alter table scouts add column if not exists age_min int;
alter table scouts add column if not exists age_max int;
alter table scouts add column if not exists preferred_foot text
  check (preferred_foot in ('left','right','both'));
alter table scouts add column if not exists preferred_height_min int;

-- ── Player attributes the scorer needs but submission never captured ──
alter table players add column if not exists league text;
alter table players add column if not exists height int;
alter table players add column if not exists foot text
  check (foot in ('left','right','both'));

-- profile_completeness and quality_score are 0..1 inputs to the scorer.
-- profile_completeness is computed on write (see
-- discoveryRepository.upsertProfileCompleteness) from how many optional
-- fields are filled in. quality_score has no automatic source — it's set
-- by admin review — so it defaults to a neutral 0.5 rather than 0, which
-- would otherwise bury every player until an admin manually scores them.
-- fraud_score defaults to 0 and is recomputed by the nightly job in
-- scheduledJobs.js from this migration's player_events table.
alter table players add column if not exists profile_completeness numeric(3,2) not null default 0;
alter table players add column if not exists quality_score numeric(3,2) not null default 0.5;
alter table players add column if not exists fraud_score numeric(3,2) not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'players_profile_completeness_range') then
    alter table players add constraint players_profile_completeness_range
      check (profile_completeness between 0 and 1);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'players_quality_score_range') then
    alter table players add constraint players_quality_score_range
      check (quality_score between 0 and 1);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'players_fraud_score_range') then
    alter table players add constraint players_fraud_score_range
      check (fraud_score between 0 and 1);
  end if;
end $$;

create index if not exists idx_players_fraud_score on players(fraud_score);

-- ── Engagement event log ──
-- views7d/saves7d/contacts7d/shares7d in discoveryEngine.js are aggregated
-- from this table at query time (see discoveryRepository.getEligiblePlayers)
-- rather than kept as denormalized counters on players — nothing to keep in
-- sync, no drift between a counter column and reality.
create table if not exists player_events (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references players(id) on delete cascade,
  actor_id uuid references auth.users(id),        -- nullable: anonymous views are still real signal
  event_type text not null check (event_type in ('view','save','contact','share')),
  ip_hash text,                                    -- sha256 of requester IP — never the raw IP
  device_hash text,                                -- sha256 of a client-supplied device id — never the raw id
  created_at timestamptz not null default now()
);

create index if not exists idx_player_events_player_type_created
  on player_events(player_id, event_type, created_at desc);
create index if not exists idx_player_events_actor on player_events(actor_id);
create index if not exists idx_player_events_created on player_events(created_at desc);

alter table player_events enable row level security;

-- Written almost exclusively by the backend's service-role client
-- (discoveryController.logEvent, which computes ip_hash/device_hash
-- server-side). This policy is defense-in-depth for any future direct
-- client write, not the primary write path: it allows inserting your own
-- actor_id or an anonymous (null) event, and nothing else — in particular
-- nobody, including the actor, can SELECT rows back out. Engagement is only
-- ever exposed pre-aggregated through the discovery API, never as a
-- queryable "who viewed what" log.
create policy "Authenticated users can log their own engagement events" on player_events
  for insert with check (auth.uid() = actor_id or actor_id is null);

-- ── Scout preference self-service ──
-- 011_ownership_and_scout_applications.sql added scouts.user_id and let a
-- scout view their own row, but never added an UPDATE policy — without
-- this, a verified scout has no way to actually set the preference columns
-- this migration just added, and discoveryEngine.js falls back to treating
-- every scout as having no stated preferences. Restricted to verified rows
-- only, so a still-pending application can't be edited into "verified" or
-- reassigned to a different user_id through this path.
create policy "Verified scouts can update their own preferences" on scouts
  for update
  using (auth.uid() = user_id and verified = true)
  with check (auth.uid() = user_id and verified = true);
