-- FUSKAMO Video Infrastructure V1
-- The product surface is built now; expensive cloud video storage/transcoding is deliberately gated.
-- No payment or support contribution grants storage access or verification.

create table if not exists video_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('player_submission','post','story','reel','profile')),
  source_type text not null default 'planned' check (source_type in ('planned','external','cloud')),
  source_url text,
  playback_url text,
  thumbnail_url text,
  duration_ms integer not null default 0 check (duration_ms >= 0),
  width integer,
  height integer,
  size_bytes bigint,
  mime_type text,
  status text not null default 'awaiting_storage' check (status in ('draft','awaiting_storage','uploading','processing','ready','failed','removed')),
  processing_progress numeric(5,2) not null default 0 check (processing_progress >= 0 and processing_progress <= 100),
  storage_key text,
  manifest_url text,
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_video_assets_owner_created on video_assets(owner_id, created_at desc);
create index if not exists idx_video_assets_status on video_assets(status, updated_at desc);
create index if not exists idx_video_assets_purpose on video_assets(purpose, status);

create table if not exists video_upload_sessions (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references video_assets(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  provider text not null default 'cloud_storage_pending',
  status text not null default 'waiting_for_storage' check (status in ('waiting_for_storage','ready','uploading','completed','expired','cancelled')),
  expected_bytes bigint,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists idx_video_upload_sessions_owner on video_upload_sessions(owner_id,created_at desc);

create table if not exists video_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references video_assets(id) on delete cascade,
  job_type text not null check (job_type in ('probe','thumbnail','transcode','package_hls','moderate','cleanup')),
  status text not null default 'queued' check (status in ('queued','running','completed','failed','cancelled')),
  attempts integer not null default 0 check (attempts >= 0),
  priority integer not null default 50 check (priority between 0 and 100),
  payload jsonb not null default '{}'::jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);
create index if not exists idx_video_jobs_queue on video_processing_jobs(status, priority desc, created_at);

create table if not exists video_storage_policy (
  id boolean primary key default true check(id),
  enabled boolean not null default false,
  provider text not null default 'not_configured',
  max_upload_bytes bigint not null default 52428800,
  max_duration_ms integer not null default 180000,
  updated_at timestamptz not null default now()
);
insert into video_storage_policy(id) values(true) on conflict(id) do nothing;

alter table video_assets enable row level security;
alter table video_upload_sessions enable row level security;
alter table video_processing_jobs enable row level security;
alter table video_storage_policy enable row level security;

create policy "Owners read video assets" on video_assets for select using(owner_id=auth.uid());
create policy "Owners create video assets" on video_assets for insert with check(owner_id=auth.uid());
create policy "Owners update video assets" on video_assets for update using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "Owners delete video assets" on video_assets for delete using(owner_id=auth.uid());

create policy "Owners read upload sessions" on video_upload_sessions for select using(owner_id=auth.uid());
create policy "Owners create upload sessions" on video_upload_sessions for insert with check(owner_id=auth.uid());
create policy "Owners cancel upload sessions" on video_upload_sessions for update using(owner_id=auth.uid()) with check(owner_id=auth.uid());

create policy "Owners read video jobs" on video_processing_jobs for select using(exists(select 1 from video_assets a where a.id=asset_id and a.owner_id=auth.uid()));

create policy "Public video policy readable" on video_storage_policy for select using(true);

create or replace function video_storage_is_ready()
returns boolean language sql stable security definer set search_path=public as $$
  select enabled from video_storage_policy where id=true;
$$;

create or replace function prepare_video_asset(
  p_purpose text,
  p_source_url text default null,
  p_mime_type text default null,
  p_size_bytes bigint default null,
  p_duration_ms integer default 0
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_purpose not in ('player_submission','post','story','reel','profile') then raise exception 'Unsupported video purpose'; end if;
  if p_duration_ms < 0 or p_duration_ms > 3600000 then raise exception 'Invalid duration'; end if;
  if p_size_bytes is not null and p_size_bytes < 0 then raise exception 'Invalid size'; end if;

  insert into video_assets(owner_id,purpose,source_type,source_url,mime_type,size_bytes,duration_ms,status)
  values(auth.uid(),p_purpose,case when p_source_url is null then 'planned' else 'external' end,p_source_url,p_mime_type,p_size_bytes,coalesce(p_duration_ms,0),case when p_source_url is null then 'awaiting_storage' else 'draft' end)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function video_launch_status()
returns table(enabled boolean, provider text, max_upload_bytes bigint, max_duration_ms integer)
language sql security definer set search_path=public as $$
  select enabled, provider, max_upload_bytes, max_duration_ms from video_storage_policy where id=true;
$$;

revoke all on function video_storage_is_ready() from public;
grant execute on function video_storage_is_ready() to authenticated;
revoke all on function prepare_video_asset(text,text,text,bigint,integer) from public;
grant execute on function prepare_video_asset(text,text,text,bigint,integer) to authenticated;
revoke all on function video_launch_status() from public;
grant execute on function video_launch_status() to anon, authenticated;
