-- FUSKAMO Reliability, security, experimentation and observability v1
create table if not exists idempotency_keys (
  key text primary key, actor_id uuid, operation text not null, response jsonb, status_code int, created_at timestamptz not null default now(), expires_at timestamptz not null
);
create index if not exists idempotency_expiry_idx on idempotency_keys(expires_at);

create table if not exists platform_outbox (
  id uuid primary key default gen_random_uuid(), topic text not null, aggregate_id uuid, payload jsonb not null default '{}'::jsonb,
  attempts int not null default 0, available_at timestamptz not null default now(), locked_at timestamptz, processed_at timestamptz, last_error text
);
create index if not exists platform_outbox_ready_idx on platform_outbox(available_at, processed_at) where processed_at is null;

create table if not exists security_events (
  id uuid primary key default gen_random_uuid(), actor_id uuid, event_type text not null, severity text not null default 'info',
  ip_hash text, user_agent_hash text, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists security_events_time_idx on security_events(created_at desc);
create index if not exists security_events_actor_idx on security_events(actor_id, created_at desc);

create table if not exists service_health_snapshots (
  id uuid primary key default gen_random_uuid(), service_name text not null, status text not null, latency_ms numeric,
  version text, metadata jsonb not null default '{}'::jsonb, checked_at timestamptz not null default now()
);
create index if not exists service_health_time_idx on service_health_snapshots(service_name, checked_at desc);

create table if not exists model_evaluations (
  id uuid primary key default gen_random_uuid(), model_name text not null, model_version text not null, dataset text not null,
  metrics jsonb not null default '{}'::jsonb, evaluated_at timestamptz not null default now()
);
create index if not exists model_eval_idx on model_evaluations(model_name, evaluated_at desc);

create table if not exists ranking_impressions (
  id uuid primary key default gen_random_uuid(), subject_id uuid, surface text not null, item_id uuid not null,
  position int not null, model_name text, model_version text, experiment_key text, variant text, score numeric,
  created_at timestamptz not null default now()
);
create index if not exists ranking_impressions_subject_idx on ranking_impressions(subject_id, created_at desc);
create index if not exists ranking_impressions_surface_idx on ranking_impressions(surface, created_at desc);

create table if not exists search_query_events (
  id uuid primary key default gen_random_uuid(), subject_id uuid, query_hash text not null, result_count int not null default 0,
  clicked_id uuid, latency_ms numeric, created_at timestamptz not null default now()
);
create index if not exists search_query_time_idx on search_query_events(created_at desc);

create table if not exists account_device_links (
  id uuid primary key default gen_random_uuid(), account_id uuid not null, device_hash text not null, first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(), risk_score numeric(6,5) not null default 0, unique(account_id, device_hash)
);
create index if not exists account_device_hash_idx on account_device_links(device_hash);

create table if not exists api_usage_windows (
  subject_key text not null, window_start timestamptz not null, request_count int not null default 0, blocked_count int not null default 0,
  primary key(subject_key, window_start)
);

create table if not exists disaster_recovery_checkpoints (
  id uuid primary key default gen_random_uuid(), backup_type text not null, location text not null, checksum text, verified boolean not null default false,
  created_at timestamptz not null default now(), verified_at timestamptz
);

alter table idempotency_keys enable row level security;
alter table platform_outbox enable row level security;
alter table security_events enable row level security;
alter table service_health_snapshots enable row level security;
alter table model_evaluations enable row level security;
alter table ranking_impressions enable row level security;
alter table search_query_events enable row level security;
alter table account_device_links enable row level security;
alter table api_usage_windows enable row level security;
alter table disaster_recovery_checkpoints enable row level security;

create policy idempotency_self_read on idempotency_keys for select using (auth.uid() = actor_id);
create policy ranking_impressions_self_read on ranking_impressions for select using (auth.uid() = subject_id);
create policy search_query_self_read on search_query_events for select using (auth.uid() = subject_id);
create policy account_device_self_read on account_device_links for select using (auth.uid() = account_id);
