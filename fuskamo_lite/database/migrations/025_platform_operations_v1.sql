-- FUSKAMO Platform Operations V1
-- Covers free-first moderation, notification routing, deep links, offline sync,
-- account security, analytics, and recommendation experimentation.

create extension if not exists pgcrypto;

-- =========================
-- 10. MODERATION / APPEALS
-- =========================
create table if not exists moderation_cases (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('user','post','comment','story','reel','group','message','profile','player','club','scout')),
  target_id uuid not null,
  reason text not null check (reason in ('spam','harassment','hate','scam','impersonation','sexual_content','violence','fraud','copyright','other')),
  description text check (char_length(description) <= 5000),
  severity smallint not null default 1 check (severity between 1 and 5),
  status text not null default 'open' check (status in ('open','triaged','investigating','actioned','dismissed','appealed','closed')),
  assigned_to uuid references auth.users(id) on delete set null,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists idx_moderation_cases_status on moderation_cases(status,severity desc,created_at desc);
create index if not exists idx_moderation_cases_target on moderation_cases(target_type,target_id);

create table if not exists moderation_evidence (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references moderation_cases(id) on delete cascade,
  submitted_by uuid references auth.users(id) on delete set null,
  evidence_type text not null check (evidence_type in ('text','url','screenshot','metadata','system_signal')),
  content text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_moderation_evidence_case on moderation_evidence(case_id,created_at);

create table if not exists moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references moderation_cases(id) on delete cascade,
  appellant_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 10 and 5000),
  status text not null default 'pending' check (status in ('pending','reviewing','upheld','overturned','closed')),
  reviewer_id uuid references auth.users(id) on delete set null,
  decision_note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index if not exists idx_moderation_appeals_status on moderation_appeals(status,created_at desc);

-- =========================
-- 11. NOTIFICATION EVENT BUS
-- =========================
create table if not exists notification_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  object_type text,
  object_id uuid,
  title text not null,
  body text,
  deep_link text,
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  read_at timestamptz
);
create unique index if not exists uq_notification_event_dedupe on notification_events(dedupe_key) where dedupe_key is not null;
create index if not exists idx_notification_events_recipient on notification_events(recipient_id,created_at desc);

create table if not exists notification_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references notification_events(id) on delete cascade,
  channel text not null check (channel in ('in_app','push','email','sms')),
  status text not null check (status in ('queued','sent','failed','skipped')),
  provider text,
  provider_message_id text,
  error_code text,
  attempted_at timestamptz not null default now()
);
create index if not exists idx_notification_delivery_event on notification_delivery_attempts(event_id,attempted_at desc);

create or replace function enqueue_notification_event(
  p_recipient uuid,p_actor uuid,p_event text,p_title text,p_body text default null,
  p_object_type text default null,p_object_id uuid default null,p_deep_link text default null,
  p_dedupe_key text default null,p_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
  insert into notification_events(recipient_id,actor_id,event_type,title,body,object_type,object_id,deep_link,dedupe_key,metadata)
  values(p_recipient,p_actor,p_event,p_title,p_body,p_object_type,p_object_id,p_deep_link,p_dedupe_key,coalesce(p_metadata,'{}'::jsonb))
  on conflict (dedupe_key) where dedupe_key is not null do update set title=excluded.title
  returning id into v_id;
  return v_id;
end $$;

-- =========================
-- 12. CANONICAL DEEP LINKS
-- =========================
create table if not exists deep_link_objects (
  id uuid primary key default gen_random_uuid(),
  path text unique not null,
  object_type text not null check (object_type in ('profile','post','reel','story','group','player','club','scout','coach','invite','message')),
  object_id uuid not null,
  canonical_title text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_deep_link_objects_object on deep_link_objects(object_type,object_id);

create or replace function canonical_profile_path(p_username text) returns text
language sql immutable as $$ select '/@' || lower(trim(both '@' from p_username)) $$;

-- =========================
-- 13. OFFLINE OUTBOX / SYNC
-- =========================
create table if not exists offline_operations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_operation_id text not null,
  operation_type text not null check (operation_type in ('create_post','like','unlike','follow','unfollow','send_message','create_comment','reaction','join_group','leave_group','vote_poll','mark_read','save','unsave')),
  target_type text,
  target_id uuid,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued','processing','applied','failed','conflict','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,client_operation_id)
);
create index if not exists idx_offline_operations_queue on offline_operations(user_id,status,created_at);

create table if not exists sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation_id uuid references offline_operations(id) on delete cascade,
  conflict_type text not null,
  server_state jsonb,
  client_state jsonb,
  resolution text check (resolution in ('server_wins','client_wins','merged','manual')),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_sync_conflicts_user on sync_conflicts(user_id,created_at desc);

-- =========================
-- 14. SECURITY / SESSIONS / RECOVERY
-- =========================
create table if not exists security_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_label text,
  platform text,
  ip_hash text,
  user_agent_hash text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);
create index if not exists idx_security_sessions_user on security_sessions(user_id,last_seen_at desc);

create table if not exists security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('login','logout','login_failed','password_changed','mfa_enabled','mfa_disabled','session_revoked','recovery_requested','recovery_used','suspicious_login','rate_limited','blocked_action')),
  risk_score numeric(6,4) not null default 0 check(risk_score between 0 and 1),
  ip_hash text,
  device_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_security_events_user on security_events(user_id,created_at desc);
create index if not exists idx_security_events_risk on security_events(risk_score desc,created_at desc);

create table if not exists account_recovery_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_recovery_codes_user on account_recovery_codes(user_id,used_at);

create table if not exists security_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  login_alerts boolean not null default true,
  new_device_alerts boolean not null default true,
  message_request_filter boolean not null default true,
  allow_search_by_email boolean not null default false,
  allow_search_by_phone boolean not null default false,
  updated_at timestamptz not null default now()
);

-- =========================
-- 15. FIRST-PARTY ANALYTICS
-- =========================
create table if not exists analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id text,
  event_name text not null,
  object_type text,
  object_id uuid,
  value numeric(12,4),
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);
create index if not exists idx_analytics_events_name_time on analytics_events(event_name,occurred_at desc);
create index if not exists idx_analytics_events_user_time on analytics_events(user_id,occurred_at desc);
create index if not exists idx_analytics_events_object_time on analytics_events(object_type,object_id,occurred_at desc);

create table if not exists analytics_daily_rollups (
  day date not null,
  metric text not null,
  object_type text,
  object_id uuid,
  value numeric(18,4) not null default 0,
  unique(day,metric,object_type,object_id)
);
create index if not exists idx_analytics_rollups_day on analytics_daily_rollups(day desc,metric);

-- =========================
-- 16. RECOMMENDATION V2 / EXPERIMENTS
-- =========================
create table if not exists recommendation_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  object_type text not null check (object_type in ('profile','post','reel','story','group','player','scout','club')),
  object_id uuid not null,
  signal text not null check (signal in ('impression','open','watch','complete','like','save','share','follow','join','skip','not_interested','mute','block','report')),
  weight numeric(12,4) not null default 1,
  session_id text,
  model_version text not null default 'unified-v2',
  created_at timestamptz not null default now()
);
create index if not exists idx_rec_feedback_user_time on recommendation_feedback(user_id,created_at desc);
create index if not exists idx_rec_feedback_object_time on recommendation_feedback(object_type,object_id,created_at desc);

create table if not exists recommendation_experiments (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  model_version text not null,
  allocation_percent smallint not null default 0 check(allocation_percent between 0 and 100),
  status text not null default 'draft' check(status in ('draft','running','paused','completed')),
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists recommendation_assignments (
  experiment_id uuid not null references recommendation_experiments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  variant text not null,
  assigned_at timestamptz not null default now(),
  primary key(experiment_id,user_id)
);

create table if not exists recommendation_user_features (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role_affinity jsonb not null default '{}'::jsonb,
  category_affinity jsonb not null default '{}'::jsonb,
  creator_affinity jsonb not null default '{}'::jsonb,
  negative_affinity jsonb not null default '{}'::jsonb,
  diversity_state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- =========================
-- RLS
-- =========================
alter table moderation_cases enable row level security;
alter table moderation_evidence enable row level security;
alter table moderation_appeals enable row level security;
alter table notification_events enable row level security;
alter table notification_delivery_attempts enable row level security;
alter table deep_link_objects enable row level security;
alter table offline_operations enable row level security;
alter table sync_conflicts enable row level security;
alter table security_sessions enable row level security;
alter table security_events enable row level security;
alter table account_recovery_codes enable row level security;
alter table security_settings enable row level security;
alter table analytics_events enable row level security;
alter table analytics_daily_rollups enable row level security;
alter table recommendation_feedback enable row level security;
alter table recommendation_experiments enable row level security;
alter table recommendation_assignments enable row level security;
alter table recommendation_user_features enable row level security;

drop policy if exists "users create reports" on moderation_cases;
create policy "users create reports" on moderation_cases for insert with check (auth.uid() = reporter_id);
drop policy if exists "users see own reports" on moderation_cases;
create policy "users see own reports" on moderation_cases for select using (auth.uid() = reporter_id or auth.uid() = target_user_id or is_platform_admin('content:moderate'));
drop policy if exists "users submit appeals" on moderation_appeals;
create policy "users submit appeals" on moderation_appeals for insert with check (auth.uid() = appellant_id);
drop policy if exists "users see own appeals" on moderation_appeals;
create policy "users see own appeals" on moderation_appeals for select using (auth.uid() = appellant_id or auth.uid() = reviewer_id or is_platform_admin('content:moderate'));

drop policy if exists "users read notification events" on notification_events;
create policy "users read notification events" on notification_events for select using (auth.uid() = recipient_id);
drop policy if exists "users mark notification events read" on notification_events;
create policy "users mark notification events read" on notification_events for update using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);

drop policy if exists "users read deep links" on deep_link_objects;
create policy "users read deep links" on deep_link_objects for select using (is_active = true);

drop policy if exists "users manage offline operations" on offline_operations;
create policy "users manage offline operations" on offline_operations for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users see own conflicts" on sync_conflicts;
create policy "users see own conflicts" on sync_conflicts for select using (auth.uid() = user_id);

drop policy if exists "users see own sessions" on security_sessions;
create policy "users see own sessions" on security_sessions for select using (auth.uid() = user_id);
drop policy if exists "users manage own security settings" on security_settings;
create policy "users manage own security settings" on security_settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "users see own security events" on security_events;
create policy "users see own security events" on security_events for select using (auth.uid() = user_id);
drop policy if exists "users see own analytics" on analytics_events;
create policy "users see own analytics" on analytics_events for select using (auth.uid() = user_id);
drop policy if exists "users write own analytics" on analytics_events;
create policy "users write own analytics" on analytics_events for insert with check (auth.uid() = user_id or user_id is null);
drop policy if exists "users see own recommendation feedback" on recommendation_feedback;
create policy "users see own recommendation feedback" on recommendation_feedback for select using (auth.uid() = user_id);
drop policy if exists "users write own recommendation feedback" on recommendation_feedback;
create policy "users write own recommendation feedback" on recommendation_feedback for insert with check (auth.uid() = user_id);
drop policy if exists "users see own recommendation features" on recommendation_user_features;
create policy "users see own recommendation features" on recommendation_user_features for select using (auth.uid() = user_id);

-- Public read of aggregate experiment configuration is deliberately not exposed to clients;
-- assignment and admin writes are service-role controlled.

-- Seed default recommendation experiments without forcing users into one.
insert into recommendation_experiments(name,model_version,allocation_percent,status,config)
values
('unified-v2-control','unified-v2',50,'running','{"ranking":"weighted","exploration":0.10,"diversity":0.15}'::jsonb),
('unified-v2-explore','unified-v2-explore',50,'running','{"ranking":"weighted","exploration":0.18,"diversity":0.20}')
on conflict(name) do nothing;

-- =========================
-- NOTIFICATION BRIDGES
-- =========================
create or replace function notify_profile_follow() returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform enqueue_notification_event(new.followed_id,new.follower_id,'follow','New follower','Someone followed your profile','profile',new.follower_id,'/@'||coalesce((select username from profiles where user_id=new.follower_id),new.follower_id::text),'follow:'||new.followed_id::text||':'||new.follower_id::text);
  return new;
end $$;
drop trigger if exists trg_notify_profile_follow on profile_follows;
create trigger trg_notify_profile_follow after insert on profile_follows for each row execute function notify_profile_follow();

create or replace function notify_post_like() returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_posts where id=new.post_id; if owner_id is not null and owner_id<>new.user_id then perform enqueue_notification_event(owner_id,new.user_id,'post_like','Post liked','Someone liked your post','post',new.post_id,'/post/'||new.post_id::text,'post_like:'||new.post_id::text||':'||new.user_id::text); end if; return new; end $$;
drop trigger if exists trg_notify_post_like on social_post_likes;
create trigger trg_notify_post_like after insert on social_post_likes for each row execute function notify_post_like();

create or replace function notify_post_comment() returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_posts where id=new.post_id; if owner_id is not null and owner_id<>new.author_id then perform enqueue_notification_event(owner_id,new.author_id,case when new.parent_id is null then 'comment' else 'comment_reply' end,case when new.parent_id is null then 'New comment' else 'New reply' end,'Someone interacted with your post','post',new.post_id,'/post/'||new.post_id::text,'post_comment:'||new.id::text); end if; return new; end $$;
drop trigger if exists trg_notify_post_comment on social_comments;
create trigger trg_notify_post_comment after insert on social_comments for each row execute function notify_post_comment();

create or replace function notify_reel_like() returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_reels where id=new.reel_id; if owner_id is not null and owner_id<>new.user_id then perform enqueue_notification_event(owner_id,new.user_id,'reel_like','Reel liked','Someone liked your reel','reel',new.reel_id,'/reel/'||new.reel_id::text,'reel_like:'||new.reel_id::text||':'||new.user_id::text); end if; return new; end $$;
drop trigger if exists trg_notify_reel_like on social_reel_likes;
create trigger trg_notify_reel_like after insert on social_reel_likes for each row execute function notify_reel_like();

create or replace function notify_direct_message() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into notification_events(recipient_id,actor_id,event_type,title,body,object_type,object_id,deep_link,dedupe_key)
  select p.user_id,new.sender_id,'message','New message','You have a new message','message',new.conversation_id,'/message/'||new.conversation_id::text,'message:'||new.id::text
  from direct_conversation_participants p
  where p.conversation_id=new.conversation_id and p.user_id<>new.sender_id;
  return new;
end $$;
drop trigger if exists trg_notify_direct_message on direct_messages;
create trigger trg_notify_direct_message after insert on direct_messages for each row execute function notify_direct_message();

create or replace function notify_group_message() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into notification_events(recipient_id,actor_id,event_type,title,body,object_type,object_id,deep_link,dedupe_key)
  select gm.user_id,new.sender_id,case when new.channel='host' then 'group_host_message' else 'group_message' end,case when new.channel='host' then 'Host update' else 'New group message' end,left(new.content,120),'group',new.group_id,'/group/'||new.group_id::text,'group_message:'||new.id::text||':'||gm.user_id::text
  from group_members gm
  where gm.group_id=new.group_id and gm.user_id<>new.sender_id and (new.channel='member' or gm.role in ('owner','host','moderator'));
  return new;
end $$;
drop trigger if exists trg_notify_group_message on group_messages;
create trigger trg_notify_group_message after insert on group_messages for each row execute function notify_group_message();

-- Refreshable first-party daily rollups. This is intentionally SQL-only and free to run as a scheduled Supabase job.
create or replace function refresh_analytics_rollup(p_day date default current_date) returns integer language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  insert into analytics_daily_rollups(day,metric,object_type,object_id,value)
  select p_day,event_name,object_type,object_id,sum(coalesce(value,1))
  from analytics_events where occurred_at>=p_day and occurred_at<p_day+1 group by event_name,object_type,object_id
  on conflict(day,metric,object_type,object_id) do update set value=excluded.value;
  get diagnostics n=row_count; return n;
end $$;
grant execute on function refresh_analytics_rollup(date) to authenticated;

-- Compatibility bridge: existing Flutter notification provider streams the legacy
-- notifications table. Every new event is mirrored there, so social/group/message
-- notifications appear instantly without a second client-side realtime channel.
create or replace function bridge_notification_event_to_legacy() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into notifications(user_id,title,body,type,read,created_at)
  values(new.recipient_id,new.title,new.body,new.event_type,false,new.created_at);
  return new;
end $$;
drop trigger if exists trg_bridge_notification_event on notification_events;
create trigger trg_bridge_notification_event after insert on notification_events for each row execute function bridge_notification_event_to_legacy();

-- Canonical-link materialization for shareable objects.
create or replace function upsert_profile_deep_link() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.username is not null and length(trim(new.username))>0 then
    insert into deep_link_objects(path,object_type,object_id,canonical_title,is_active) values('/@'||lower(new.username),'profile',new.user_id,new.username,true)
    on conflict(path) do update set object_id=excluded.object_id,canonical_title=excluded.canonical_title,is_active=true,updated_at=now();
  end if; return new;
end $$;
drop trigger if exists trg_profile_deep_link on profiles;
create trigger trg_profile_deep_link after insert or update of username on profiles for each row execute function upsert_profile_deep_link();

create or replace function upsert_post_deep_link() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into deep_link_objects(path,object_type,object_id,canonical_title,is_active) values('/post/'||new.id::text,'post',new.id,left(new.body,80),new.status='published') on conflict(path) do update set is_active=(new.status='published'),updated_at=now(); return new;
end $$;
drop trigger if exists trg_post_deep_link on social_posts;
create trigger trg_post_deep_link after insert or update of status on social_posts for each row execute function upsert_post_deep_link();

create or replace function upsert_reel_deep_link() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into deep_link_objects(path,object_type,object_id,canonical_title,is_active) values('/reel/'||new.id::text,'reel',new.id,left(new.caption,80),new.status='published') on conflict(path) do update set is_active=(new.status='published'),updated_at=now(); return new;
end $$;
drop trigger if exists trg_reel_deep_link on social_reels;
create trigger trg_reel_deep_link after insert or update of status on social_reels for each row execute function upsert_reel_deep_link();

create or replace function upsert_group_deep_link() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.slug is not null then insert into deep_link_objects(path,object_type,object_id,canonical_title,is_active) values('/group/'||lower(new.slug),'group',new.id,new.name,new.privacy<>'secret') on conflict(path) do update set is_active=(new.privacy<>'secret'),canonical_title=new.name,updated_at=now(); end if; return new;
end $$;
drop trigger if exists trg_group_deep_link on groups;
create trigger trg_group_deep_link after insert or update of slug,privacy,name on groups for each row execute function upsert_group_deep_link();

alter table notifications add column if not exists deep_link text;
-- Update the bridge so legacy notification rows retain canonical navigation.
create or replace function bridge_notification_event_to_legacy() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into notifications(user_id,title,body,type,read,created_at,deep_link)
  values(new.recipient_id,new.title,new.body,new.event_type,false,new.created_at,new.deep_link);
  return new;
end $$;

create or replace function resolve_moderation_case(p_case uuid,p_status text,p_resolution text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_platform_admin('content:moderate') then raise exception 'Moderation permission required'; end if;
  update moderation_cases set status=p_status,resolution=p_resolution,assigned_to=auth.uid(),updated_at=now(),resolved_at=case when p_status in ('actioned','dismissed','closed') then now() else null end where id=p_case;
end $$;
grant execute on function resolve_moderation_case(uuid,text,text) to authenticated;

create or replace function decide_moderation_appeal(p_appeal uuid,p_status text,p_note text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_platform_admin('content:moderate') then raise exception 'Moderation permission required'; end if;
  update moderation_appeals set status=p_status,reviewer_id=auth.uid(),decision_note=p_note,decided_at=now() where id=p_appeal;
end $$;
grant execute on function decide_moderation_appeal(uuid,text,text) to authenticated;
