-- FUSKAMO Platform Intelligence v1
create extension if not exists pgcrypto;

create table if not exists platform_events (
  id uuid primary key default gen_random_uuid(), event_type text not null, actor_id uuid, subject_id uuid,
  payload jsonb not null default '{}'::jsonb, request_id text, occurred_at timestamptz not null default now(), version int not null default 1
);
create index if not exists platform_events_type_time_idx on platform_events(event_type, occurred_at desc);
create index if not exists platform_events_actor_time_idx on platform_events(actor_id, occurred_at desc);

create table if not exists user_features (
  user_id uuid primary key, features jsonb not null default '{}'::jsonb, model_version text not null default 'v1', updated_at timestamptz not null default now()
);
create table if not exists content_features (
  content_id uuid primary key, features jsonb not null default '{}'::jsonb, model_version text not null default 'v1', updated_at timestamptz not null default now()
);

create table if not exists search_documents (
  id uuid primary key, entity_type text not null, searchable_text text not null, document jsonb not null default '{}'::jsonb,
  search_vector tsvector generated always as (to_tsvector('simple', searchable_text)) stored, updated_at timestamptz not null default now()
);
create index if not exists search_documents_vector_idx on search_documents using gin(search_vector);

create table if not exists experiments (
  key text primary key, description text, enabled boolean not null default false, rollout_percent numeric(5,2) not null default 0,
  variants jsonb not null default '["control","treatment"]'::jsonb, config jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists experiment_assignments (
  experiment_key text not null references experiments(key) on delete cascade, subject_id uuid not null, variant text not null,
  assigned_at timestamptz not null default now(), primary key(experiment_key, subject_id)
);

create table if not exists analytics_events (
  id uuid primary key default gen_random_uuid(), event_type text not null, subject_id uuid, properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists analytics_events_type_time_idx on analytics_events(event_type, occurred_at desc);

create table if not exists abuse_signals (
  id uuid primary key default gen_random_uuid(), subject_id uuid not null, signal_type text not null, score numeric(6,5) not null default 0,
  evidence jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists abuse_signals_subject_time_idx on abuse_signals(subject_id, created_at desc);

create table if not exists media_assets (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null, kind text not null check(kind in ('image','video','audio','document')),
  mime_type text not null, bytes bigint not null check(bytes > 0), object_key text not null unique, status text not null default 'pending',
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), published_at timestamptz
);
create table if not exists media_variants (
  id uuid primary key default gen_random_uuid(), asset_id uuid not null references media_assets(id) on delete cascade,
  variant_key text not null, object_key text not null, width int, height int, bitrate int, bytes bigint, status text not null default 'pending',
  unique(asset_id, variant_key)
);

create table if not exists notification_delivery_log (
  id uuid primary key default gen_random_uuid(), notification_id uuid, recipient_id uuid not null, channel text not null,
  status text not null, reason text, delivered_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists notification_delivery_recipient_idx on notification_delivery_log(recipient_id, created_at desc);

create table if not exists realtime_presence (
  user_id uuid primary key, state text not null default 'offline', last_seen_at timestamptz not null default now(), metadata jsonb not null default '{}'::jsonb
);

create table if not exists creator_metric_snapshots (
  id uuid primary key default gen_random_uuid(), creator_id uuid not null, period_start date not null, period_end date not null,
  metrics jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), unique(creator_id, period_start, period_end)
);

alter table platform_events enable row level security;
alter table user_features enable row level security;
alter table content_features enable row level security;
alter table search_documents enable row level security;
alter table experiments enable row level security;
alter table experiment_assignments enable row level security;
alter table analytics_events enable row level security;
alter table abuse_signals enable row level security;
alter table media_assets enable row level security;
alter table media_variants enable row level security;
alter table notification_delivery_log enable row level security;
alter table realtime_presence enable row level security;
alter table creator_metric_snapshots enable row level security;

-- Users may read their own operational state; privileged writes remain server-side.
create policy platform_events_self_read on platform_events for select using (auth.uid() = actor_id);
create policy user_features_self_read on user_features for select using (auth.uid() = user_id);
create policy analytics_self_read on analytics_events for select using (auth.uid() = subject_id);
create policy abuse_self_read on abuse_signals for select using (auth.uid() = subject_id);
create policy media_owner_read on media_assets for select using (auth.uid() = owner_id);
create policy media_owner_write on media_assets for insert with check (auth.uid() = owner_id);
create policy media_owner_update on media_assets for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy media_owner_variants_read on media_variants for select using (exists(select 1 from media_assets a where a.id=asset_id and a.owner_id=auth.uid()));
create policy presence_self_read on realtime_presence for select using (auth.uid() = user_id);
create policy creator_metrics_self_read on creator_metric_snapshots for select using (auth.uid() = creator_id);
