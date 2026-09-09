-- FUSKAMO Player Discovery V2
-- Additive migration: V1 discovery remains intact and can be used as fallback.

-- V2 uses the existing player_events table, but needs negative feedback and
-- lightweight client metadata for safer candidate ranking. Metadata is JSONB
-- so adding new event context does not require a migration every time.
do $$
begin
  if exists (select 1 from pg_constraint where conrelid = 'player_events'::regclass and conname = 'player_events_event_type_check') then
    alter table player_events drop constraint player_events_event_type_check;
  end if;
exception when undefined_table then
  null;
end $$;

alter table player_events add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table player_events add constraint player_events_event_type_check
  check (event_type in ('view','save','contact','share','skip','hide','report'));

create index if not exists idx_player_events_actor_recent
  on player_events(actor_id, created_at desc, player_id);
create index if not exists idx_player_events_negative
  on player_events(player_id, event_type, created_at desc)
  where event_type in ('skip','hide','report');

-- Ranking impressions provide reproducible auditability for model/experiment
-- changes. RLS remains enabled from migration 029.
alter table ranking_impressions add column if not exists score numeric;
alter table ranking_impressions add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Explicitly expose the V2 model configuration used by the service. This is
-- configuration, not model weights learned from users; learned models can be
-- registered later through backend/src/ml/modelRegistry.js.
create table if not exists player_discovery_model_configs (
  name text not null,
  version text not null,
  enabled boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(name, version)
);

alter table player_discovery_model_configs enable row level security;

insert into player_discovery_model_configs(name, version, enabled, config)
values (
  'player-discovery-utility', 'v2.0.0', true,
  '{"type":"deterministic-utility","explorationRate":0.12,"countryCap":3,"clubCap":2}'::jsonb
)
on conflict (name, version) do nothing;
