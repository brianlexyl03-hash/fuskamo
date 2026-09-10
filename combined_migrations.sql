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
create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  checkout_request_id text unique not null,
  merchant_request_id text,
  phone_number text not null,
  amount numeric not null,
  account_reference text,
  status text not null default 'pending' check (status in ('pending','completed','failed')),
  mpesa_receipt_number text,
  result_desc text,
  created_at timestamptz default now()
);
create index if not exists idx_transactions_status on transactions(status);
create index if not exists idx_transactions_phone on transactions(phone_number);
create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor text not null, action text not null,
  target_type text not null, target_id text not null,
  metadata jsonb default '{}', created_at timestamptz default now()
);
create index if not exists idx_audit_logs_target on audit_logs(target_type, target_id);
create table if not exists ai_usage_logs (
  id uuid primary key default gen_random_uuid(),
  prompt_name text not null, prompt_version text not null, model text not null,
  prompt_tokens int, completion_tokens int, total_tokens int,
  estimated_cost_usd numeric, created_at timestamptz default now()
);
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null, title text not null, body text, type text,
  read boolean default false, created_at timestamptz default now()
);
create table if not exists notification_preferences (
  user_id uuid primary key,
  sms_enabled boolean default true, email_enabled boolean default true, push_enabled boolean default true
);
create index if not exists idx_notifications_user on notifications(user_id, read);
-- Backs PushNotificationService (lib/notifications/push_notification_service.dart).
-- One row per device/token; a user can have several (phone + tablet).
create table if not exists device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios','android')),
  updated_at timestamptz not null default now()
);

alter table device_tokens enable row level security;

-- Users manage only their own device rows; the backend's service-role key
-- (used to actually send pushes) bypasses RLS entirely, same as it does
-- for notifications — see backend/src/services.
create policy "Users manage their own device tokens" on device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_device_tokens_user on device_tokens(user_id);
-- 005_notifications.sql created these tables without RLS. That's fine as
-- long as only the backend's service-role client ever touches them, but
-- notification_provider.dart / notification_service.dart now read
-- `notifications` directly from Flutter with the anon key — so RLS has to
-- actually scope rows to their owner before that's safe.
alter table notifications enable row level security;
alter table notification_preferences enable row level security;

-- Read/mark-read only — inserts stay backend-only (service role bypasses
-- RLS entirely), matching notificationRepository.js's comment that rows
-- are always written server-side.
create policy "Users read their own notifications" on notifications
  for select using (auth.uid() = user_id);

create policy "Users mark their own notifications read" on notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their own notification preferences" on notification_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- Backs the "boost submission" M-Pesa flow: a player row featured until
-- this timestamp sorts first in the feed (see PlayerService.fetchApprovedPlayers
-- in the Flutter app, which orders by featured_until first).
alter table players add column if not exists featured_until timestamptz;

create index if not exists idx_players_featured on players(featured_until);
-- Real "Contact" buttons need something to contact. Neither players nor
-- scouts had any contact field before this — CONTACT on a player card was
-- a fake toast with nowhere to actually send anything (see
-- lib/widgets/player_card.dart). Both optional: submitters aren't forced
-- to expose contact info, and the app degrades honestly (an explicit
-- "no contact info on file" state, not a fake success message) when it's
-- missing.
alter table players add column if not exists contact_email text;
alter table players add column if not exists contact_phone text;
alter table scouts add column if not exists contact_email text;
alter table scouts add column if not exists contact_phone text;
-- Backs the real "save player" bookmark (was a fake toast before this —
-- see lib/widgets/player_card.dart / lib/providers/saved_players_provider.dart).
-- Requires being signed in — see AuthProvider — since a save is tied to a user.
create table if not exists saved_players (
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, player_id)
);

alter table saved_players enable row level security;

create policy "Users manage their own saved players" on saved_players
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_saved_players_user on saved_players(user_id, created_at desc);
-- Links a submission back to the account that made it — needed for "My
-- Submissions" (Profile screen), the boost-payment notification that
-- previously had nowhere to send, and the new approve/reject
-- notifications in playerAdminRepository.js. Nullable: submitting a player
-- has never required signing in, so older/anonymous rows simply have no
-- owner and won't show up in anyone's "My Submissions" list.
alter table players add column if not exists submitted_by uuid references auth.users(id);
create index if not exists idx_players_submitted_by on players(submitted_by);

create policy "Owners can view their own submissions" on players
  for select using (auth.uid() = submitted_by);

-- Scout applications: reuses `verified` as the review flag (false =
-- pending, true = listed) instead of adding a parallel status column.
-- user_id is nullable for the same reason as players.submitted_by above.
--
-- Correction: an earlier round of work claimed scouts had no RLS at all
-- and "fixed" that here — that was wrong. 001_players_scouts.sql already
-- ran `alter table scouts enable row level security` and created the
-- "Public can view verified scouts" policy. Re-declaring either of those
-- here would fail with a duplicate-policy error on a fresh database, so
-- this migration only adds what 001 didn't already cover: the insert
-- policy for applications, and owners viewing their own (unverified) row.
alter table scouts add column if not exists user_id uuid references auth.users(id);
create index if not exists idx_scouts_user_id on scouts(user_id);

create policy "Anyone can apply as a scout" on scouts
  for insert with check (verified = false);

create policy "Owners can view their own scout application" on scouts
  for select using (auth.uid() = user_id);
-- Fixes the 3 CRITICAL "RLS Disabled in Public" findings from the
-- Supabase security advisor. These tables are written/read only by the
-- backend via the service_role key (which bypasses RLS entirely), so we
-- just lock them down with no public policies -- nothing else should
-- ever query them directly.
alter table transactions enable row level security;
alter table audit_logs enable row level security;
alter table ai_usage_logs enable row level security;
-- Replaces the shared ADMIN_API_KEY entirely. Every administrator now has
-- their own Supabase Auth account (auth.users), a role, and a set of
-- granular permissions. See docs/admin-access.md for the full design.

-- ===== Roles =====
create table if not exists admin_roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  is_system boolean not null default false, -- system roles can't be deleted/renamed
  created_at timestamptz not null default now()
);

-- ===== Permissions catalog (resource + action pairs) =====
create table if not exists admin_permissions (
  id uuid primary key default gen_random_uuid(),
  resource text not null,   -- e.g. 'players', 'scouts', 'transactions', 'admins', 'analytics', 'settings'
  action text not null,     -- e.g. 'view', 'approve', 'reject', 'refund', 'manage', 'export'
  description text not null default '',
  unique (resource, action)
);

create table if not exists admin_role_permissions (
  role_id uuid not null references admin_roles(id) on delete cascade,
  permission_id uuid not null references admin_permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- ===== Admin accounts, one row per auth.users admin =====
create table if not exists admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null default '',
  role_id uuid not null references admin_roles(id),
  status text not null default 'active'
    check (status in ('active', 'disabled', 'suspended', 'revoked')),
  mfa_enabled boolean not null default false,
  failed_login_count integer not null default 0,
  locked_until timestamptz,
  last_login_at timestamptz,
  created_by uuid references admin_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_admin_users_status on admin_users(status);
create index if not exists idx_admin_users_role on admin_users(role_id);

-- ===== Session tracking, for "logout everywhere" / per-session revocation =====
-- Supabase Auth owns the actual refresh tokens; this table is our own record
-- of active sessions so an admin (or a Super Admin acting on their behalf)
-- can see and revoke them individually. A row is created on login and
-- updated on each authenticated request (last_seen_at); revoke_all calls
-- Supabase's own auth.admin.signOut(userId, 'global') AND marks these rows
-- revoked, so both layers agree.
create table if not exists admin_sessions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references admin_users(id) on delete cascade,
  session_id text not null, -- Supabase JWT 'session_id' (sid) claim
  ip_address inet,
  user_agent text,
  device_label text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  expires_at timestamptz
);
create index if not exists idx_admin_sessions_admin on admin_sessions(admin_id);
create unique index if not exists idx_admin_sessions_session_id on admin_sessions(session_id);

-- ===== Expand audit_logs with structured admin/session/network context =====
-- Keeps the existing `actor` text column (human-readable, e.g. an email)
-- for backward compatibility with rows written before this migration and
-- with non-admin callers of auditLog(); adds proper foreign keys and
-- request metadata for everything written from here on.
alter table audit_logs add column if not exists admin_id uuid references admin_users(id);
alter table audit_logs add column if not exists ip_address inet;
alter table audit_logs add column if not exists user_agent text;
alter table audit_logs add column if not exists session_id text;
create index if not exists idx_audit_logs_admin on audit_logs(admin_id);

-- ===== Row Level Security =====
-- All access to these tables goes through the backend's service-role
-- client, which bypasses RLS by design (same pattern as every other table
-- in this schema — see docs/data-handling.md). RLS is still enabled here,
-- with zero policies, so that if the anon or authenticated key is ever
-- used against these tables by mistake, the default is deny, not "open
-- table because RLS was never turned on."
alter table admin_roles enable row level security;
alter table admin_permissions enable row level security;
alter table admin_role_permissions enable row level security;
alter table admin_users enable row level security;
alter table admin_sessions enable row level security;

-- ===== Seed: permission catalog =====
insert into admin_permissions (resource, action, description) values
  ('users',         'view',    'View end-user accounts'),
  ('users',         'manage',  'Edit or deactivate end-user accounts'),
  ('players',       'view',    'View player submissions'),
  ('players',       'approve', 'Approve or reject pending player submissions'),
  ('scouts',        'view',    'View scout applications'),
  ('scouts',        'approve', 'Approve or reject pending scout applications'),
  ('verification',  'manage',  'Manage identity/organization verification decisions'),
  ('payments',      'view',    'View transactions and payment history'),
  ('payments',      'refund',  'Issue refunds or reverse transactions'),
  ('content',       'view',    'View user-submitted content (reports, flags)'),
  ('content',       'moderate','Remove, hide, or restore content'),
  ('reports',       'view',    'View user-submitted reports/flags'),
  ('reports',       'resolve', 'Resolve or dismiss reports'),
  ('analytics',     'view',    'View platform stats and analytics dashboards'),
  ('analytics',     'export',  'Export analytics/reports data'),
  ('settings',      'manage',  'Change platform-wide settings'),
  ('audit',         'view',    'View the admin audit log'),
  ('admins',        'view',    'View the list of administrator accounts'),
  ('admins',        'manage',  'Create, disable, suspend, reactivate, or revoke administrator accounts'),
  ('admins',        'assign_role', 'Change another administrator''s role')
on conflict (resource, action) do nothing;

-- ===== Seed: default roles =====
insert into admin_roles (name, description, is_system) values
  ('Super Admin', 'Full access to every resource, including managing other administrators.', true),
  ('Admin',       'Full operational access — players, scouts, payments, content, analytics. Cannot manage other admins.', true),
  ('Moderator',   'Reviews and moderates player/scout submissions and user-generated content.', true),
  ('Support',     'Read-only access for handling user support requests.', true)
on conflict (name) do nothing;

-- Super Admin: every permission
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Super Admin'
on conflict do nothing;

-- Admin: everything except admin-account management
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Admin' and p.resource <> 'admins'
on conflict do nothing;

-- Moderator: submissions + content + reports, read-only elsewhere
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Moderator'
  and (
    p.resource in ('players', 'scouts', 'content', 'reports')
    or (p.resource in ('analytics', 'payments', 'users') and p.action = 'view')
  )
on conflict do nothing;

-- Support: view-only across the board
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Support' and p.action = 'view'
on conflict do nothing;
-- Performance indexes found missing during a full production audit.
-- None of these change behavior — every query these support already
-- works, they just table-scan without the index below.

-- saved_players.player_id had no index at all (only user_id did, via the
-- composite primary key). Needed for "who saved this player" and for the
-- planner to use an index rather than a full scan on the cascade delete
-- from players.
create index if not exists idx_saved_players_player on saved_players(player_id);

-- notifications was indexed on (user_id, read) but the actual notification
-- feed query orders by created_at desc — add it to the index so that sort
-- doesn't happen in memory on every load.
create index if not exists idx_notifications_user_created on notifications(user_id, created_at desc);

-- ai_usage_logs had no index at all — fine at low volume, but any cost
-- reporting/date-range query (docs/production-checklist.md's AI cost
-- tracking) will table-scan the whole log without this once it grows.
create index if not exists idx_ai_usage_logs_created on ai_usage_logs(created_at desc);
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
-- FUSKAMO Communities / Groups
-- Any authenticated user can create a group. The creator becomes OWNER + HOST.

create table if not exists groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-_-]{2,39}$'),
  description text not null default '' check (char_length(description) <= 500),
  category text not null default 'General Football',
  avatar_url text,
  privacy text not null default 'public' check (privacy in ('public','private','secret')),
  join_approval boolean not null default false,
  allow_member_invites boolean not null default true,
  allow_member_mentions boolean not null default true,
  verified boolean not null default false,
  member_count integer not null default 0 check (member_count >= 0),
  host_count integer not null default 0 check (host_count >= 0),
  message_count bigint not null default 0 check (message_count >= 0),
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','host','moderator','member')),
  display_name text not null default 'Member' check (char_length(trim(display_name)) between 1 and 60),
  joined_at timestamptz not null default now(),
  muted_until timestamptz,
  unique(group_id, user_id)
);

create table if not exists group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null default 'Member',
  channel text not null default 'member' check (channel in ('member','host')),
  content text not null check (char_length(trim(content)) between 1 and 4000),
  reply_to_id uuid references group_messages(id) on delete set null,
  message_type text not null default 'text' check (message_type in ('text','announcement','poll','system')),
  client_message_id text,
  is_pinned boolean not null default false,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(sender_id, client_message_id)
);

create table if not exists group_message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references group_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (emoji in ('👍','❤️','😂','🔥','👏','⚽')),
  created_at timestamptz not null default now(),
  unique(message_id, user_id, emoji)
);

create table if not exists group_polls (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  creator_id uuid not null references auth.users(id) on delete cascade,
  question text not null check (char_length(trim(question)) between 2 and 500),
  multiple_choice boolean not null default false,
  anonymous boolean not null default false,
  closes_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists group_poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references group_polls(id) on delete cascade,
  label text not null check (char_length(trim(label)) between 1 and 120),
  position integer not null,
  unique(poll_id, position)
);

create table if not exists group_poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references group_polls(id) on delete cascade,
  option_id uuid not null references group_poll_options(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(poll_id, option_id, user_id)
);

create table if not exists group_pins (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  message_id uuid references group_messages(id) on delete cascade,
  poll_id uuid references group_polls(id) on delete cascade,
  pinned_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check ((message_id is not null) <> (poll_id is not null))
);

create table if not exists group_join_requests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  unique(group_id, user_id)
);

create table if not exists group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz,
  max_uses integer,
  uses integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  check (max_uses is null or max_uses > 0)
);

create table if not exists group_read_state (
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key(group_id, user_id)
);

create table if not exists group_mutes (
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  muted_until timestamptz,
  created_at timestamptz not null default now(),
  primary key(group_id, user_id)
);

create table if not exists group_reports (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid references group_messages(id) on delete set null,
  reported_user_id uuid references auth.users(id) on delete set null,
  reason text not null check (reason in ('spam','harassment','hate','scam','impersonation','sexual','violence','other')),
  details text,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now()
);

create table if not exists group_events (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('impression','open','join','leave','message','poll_vote','reaction','share','report')),
  created_at timestamptz not null default now()
);

create index if not exists idx_groups_privacy_activity on groups(privacy, last_activity_at desc);
create index if not exists idx_groups_category_activity on groups(category, last_activity_at desc);
create index if not exists idx_groups_owner on groups(owner_id);
create index if not exists idx_group_members_user on group_members(user_id, joined_at desc);
create index if not exists idx_group_members_group_role on group_members(group_id, role);
create index if not exists idx_group_messages_group_channel_created on group_messages(group_id, channel, created_at desc);
create index if not exists idx_group_messages_sender on group_messages(sender_id, created_at desc);
create index if not exists idx_group_reactions_message on group_message_reactions(message_id);
create index if not exists idx_group_polls_group_created on group_polls(group_id, created_at desc);
create index if not exists idx_group_votes_poll on group_poll_votes(poll_id);
create index if not exists idx_group_events_group_created on group_events(group_id, created_at desc);
create index if not exists idx_group_reports_status on group_reports(status, created_at desc);

alter table groups enable row level security;
alter table group_members enable row level security;
alter table group_messages enable row level security;
alter table group_message_reactions enable row level security;
alter table group_polls enable row level security;
alter table group_poll_options enable row level security;
alter table group_poll_votes enable row level security;
alter table group_pins enable row level security;
alter table group_join_requests enable row level security;
alter table group_invites enable row level security;
alter table group_read_state enable row level security;
alter table group_mutes enable row level security;
alter table group_reports enable row level security;
alter table group_events enable row level security;

create or replace function public.is_group_member(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from group_members where group_id = p_group_id and user_id = p_user_id); $$;

create or replace function public.is_group_staff(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from group_members where group_id = p_group_id and user_id = p_user_id and role in ('owner','host','moderator')); $$;

create or replace function public.is_group_owner(p_group_id uuid, p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from group_members where group_id = p_group_id and user_id = p_user_id and role = 'owner'); $$;

-- Public groups are discoverable. Private groups are visible to members.
-- Secret groups are visible only to members.
drop policy if exists "groups_select" on groups;
create policy "groups_select" on groups for select using (
  privacy = 'public' or is_group_member(id)
);

-- Direct inserts are intentionally restricted to owner_id = current user.
-- The UI uses create_group() for atomic owner membership creation.
drop policy if exists "groups_insert" on groups;
create policy "groups_insert" on groups for insert with check (auth.uid() = owner_id);

drop policy if exists "groups_update" on groups;
create policy "groups_update" on groups for update using (is_group_owner(id)) with check (is_group_owner(id));

drop policy if exists "groups_delete" on groups;
create policy "groups_delete" on groups for delete using (is_group_owner(id));

drop policy if exists "group_members_select" on group_members;
create policy "group_members_select" on group_members for select using (is_group_member(group_id));

drop policy if exists "group_members_insert" on group_members;
create policy "group_members_insert" on group_members for insert with check (
  auth.uid() = user_id and exists(select 1 from groups g where g.id = group_id and g.privacy = 'public' and g.join_approval = false)
);

drop policy if exists "group_members_update_staff" on group_members;
create policy "group_members_update_staff" on group_members for update using (is_group_staff(group_id)) with check (is_group_staff(group_id));

drop policy if exists "group_members_delete_self_or_staff" on group_members;
create policy "group_members_delete_self_or_staff" on group_members for delete using ((auth.uid() = user_id and role <> 'owner') or (is_group_staff(group_id) and role <> 'owner'));

-- Message visibility is channel-aware: host chat never leaks to ordinary members.
drop policy if exists "group_messages_select" on group_messages;
create policy "group_messages_select" on group_messages for select using (
  is_group_member(group_id) and (channel = 'member' or is_group_staff(group_id))
);

drop policy if exists "group_messages_insert" on group_messages;
create policy "group_messages_insert" on group_messages for insert with check (
  auth.uid() = sender_id and is_group_member(group_id) and (channel = 'member' or is_group_staff(group_id))
);

drop policy if exists "group_messages_update" on group_messages;
create policy "group_messages_update" on group_messages for update using (
  (auth.uid() = sender_id and channel = 'member') or is_group_staff(group_id)
) with check (
  (auth.uid() = sender_id and channel = 'member') or is_group_staff(group_id)
);

drop policy if exists "group_messages_delete" on group_messages;
create policy "group_messages_delete" on group_messages for delete using (auth.uid() = sender_id or is_group_staff(group_id));

create policy "group_reactions_select" on group_message_reactions for select using (is_group_member((select group_id from group_messages where id = message_id)));
create policy "group_reactions_insert" on group_message_reactions for insert with check (auth.uid() = user_id and is_group_member((select group_id from group_messages where id = message_id)));
create policy "group_reactions_delete" on group_message_reactions for delete using (auth.uid() = user_id);

create policy "group_polls_select" on group_polls for select using (is_group_member(group_id));
create policy "group_polls_insert" on group_polls for insert with check (auth.uid() = creator_id and is_group_staff(group_id));
create policy "group_polls_update" on group_polls for update using (is_group_staff(group_id)) with check (is_group_staff(group_id));
create policy "group_poll_options_select" on group_poll_options for select using (is_group_member((select group_id from group_polls where id = poll_id)));
create policy "group_poll_options_insert" on group_poll_options for insert with check (is_group_staff((select group_id from group_polls where id = poll_id)));
create policy "group_poll_votes_select" on group_poll_votes for select using (is_group_member((select group_id from group_polls where id = poll_id)));
create policy "group_poll_votes_insert" on group_poll_votes for insert with check (auth.uid() = user_id and is_group_member((select group_id from group_polls where id = poll_id)));
create policy "group_poll_votes_delete" on group_poll_votes for delete using (auth.uid() = user_id);

create policy "group_pins_select" on group_pins for select using (is_group_member(group_id));
create policy "group_pins_staff" on group_pins for all using (is_group_staff(group_id)) with check (is_group_staff(group_id));

create policy "join_requests_self_or_staff" on group_join_requests for select using (auth.uid() = user_id or is_group_staff(group_id));
create policy "join_requests_self_insert" on group_join_requests for insert with check (auth.uid() = user_id and not is_group_member(group_id));
create policy "join_requests_staff_update" on group_join_requests for update using (is_group_staff(group_id)) with check (is_group_staff(group_id));

create policy "group_invites_staff" on group_invites for all using (is_group_staff(group_id)) with check (is_group_staff(group_id));
create policy "group_read_state_self" on group_read_state for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "group_mutes_self_or_staff" on group_mutes for all using (auth.uid() = user_id or is_group_staff(group_id)) with check (auth.uid() = user_id or is_group_staff(group_id));
create policy "group_reports_insert" on group_reports for insert with check (auth.uid() = reporter_id and is_group_member(group_id));
create policy "group_reports_self_or_staff" on group_reports for select using (auth.uid() = reporter_id or is_group_staff(group_id));
create policy "group_events_insert" on group_events for insert with check (auth.uid() = actor_id and is_group_member(group_id));

-- Keep denormalized counters and activity timestamps correct.
create or replace function public.touch_group_activity()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  update groups
     set last_activity_at = new.created_at,
         message_count = message_count + 1,
         updated_at = now()
   where id = new.group_id;
  insert into group_events(group_id, actor_id, event_type) values (new.group_id, new.sender_id, 'message');
  return new;
end;
$$;
drop trigger if exists trg_group_message_activity on group_messages;
create trigger trg_group_message_activity after insert on group_messages for each row execute function public.touch_group_activity();

create or replace function public.sync_group_member_counts()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  update groups g set
    member_count = (select count(*) from group_members gm where gm.group_id = coalesce(new.group_id, old.group_id)),
    host_count = (select count(*) from group_members gm where gm.group_id = coalesce(new.group_id, old.group_id) and gm.role in ('owner','host','moderator')),
    updated_at = now()
  where g.id = coalesce(new.group_id, old.group_id);
  return coalesce(new, old);
end;
$$;
drop trigger if exists trg_group_member_counts on group_members;
create trigger trg_group_member_counts after insert or update or delete on group_members for each row execute function public.sync_group_member_counts();

create or replace function public.create_group(
  p_name text,
  p_slug text,
  p_description text,
  p_category text,
  p_privacy text,
  p_avatar_url text default null,
  p_join_approval boolean default false,
  p_allow_member_invites boolean default true,
  p_allow_member_mentions boolean default true,
  p_display_name text default 'Host'
)
returns groups language plpgsql security definer set search_path = public
as $$
declare g groups;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_privacy not in ('public','private','secret') then raise exception 'Invalid privacy'; end if;
  insert into groups(owner_id,name,slug,description,category,privacy,avatar_url,join_approval,allow_member_invites,allow_member_mentions)
  values(auth.uid(),trim(p_name),lower(trim(p_slug)),coalesce(p_description,''),coalesce(nullif(trim(p_category),''),'General Football'),p_privacy,p_avatar_url,p_join_approval,p_allow_member_invites,p_allow_member_mentions)
  returning * into g;
  insert into group_members(group_id,user_id,role,display_name) values(g.id,auth.uid(),'owner',coalesce(nullif(trim(p_display_name),''),'Host'));
  return g;
end;
$$;

create or replace function public.join_group(p_group_id uuid, p_display_name text default 'Member')
returns text language plpgsql security definer set search_path = public
as $$
declare g groups;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into g from groups where id = p_group_id;
  if g.id is null then raise exception 'Group not found'; end if;
  if g.privacy = 'secret' then raise exception 'This group requires an invite'; end if;
  if exists(select 1 from group_members where group_id=p_group_id and user_id=auth.uid()) then return 'already_member'; end if;
  if g.privacy='private' or g.join_approval then
    insert into group_join_requests(group_id,user_id) values(p_group_id,auth.uid()) on conflict(group_id,user_id) do update set status='pending', reviewed_at=null, reviewed_by=null;
    return 'requested';
  end if;
  insert into group_members(group_id,user_id,role,display_name) values(p_group_id,auth.uid(),'member',coalesce(nullif(trim(p_display_name),''),'Member'));
  insert into group_events(group_id,actor_id,event_type) values(p_group_id,auth.uid(),'join');
  return 'joined';
end;
$$;

create or replace function public.mark_group_read(p_group_id uuid)
returns void language sql security definer set search_path = public
as $$
  insert into group_read_state(group_id,user_id,last_read_at) values(p_group_id,auth.uid(),now())
  on conflict(group_id,user_id) do update set last_read_at=excluded.last_read_at;
$$;

create or replace function public.get_my_group_home(p_limit int default 50)
returns table(
  id uuid,name text,slug text,description text,category text,avatar_url text,privacy text,verified boolean,member_count integer,host_count integer,last_activity_at timestamptz,joined boolean,role text,display_name text,unread_count bigint,latest_message text,latest_sender text,latest_channel text
) language sql stable security definer set search_path = public
as $$
  select g.id,g.name,g.slug,g.description,g.category,g.avatar_url,g.privacy,g.verified,g.member_count,g.host_count,g.last_activity_at,
         true, gm.role, gm.display_name,
         (select count(*) from group_messages m left join group_read_state rs on rs.group_id=g.id and rs.user_id=auth.uid() where m.group_id=g.id and m.channel='member' and m.created_at > coalesce(rs.last_read_at,'epoch'::timestamptz) and m.sender_id <> auth.uid()),
         (select m.content from group_messages m where m.group_id=g.id and m.channel='member' and m.deleted_at is null order by m.created_at desc limit 1),
         (select m.sender_name from group_messages m where m.group_id=g.id and m.channel='member' and m.deleted_at is null order by m.created_at desc limit 1),
         (select m.channel from group_messages m where m.group_id=g.id and m.deleted_at is null order by m.created_at desc limit 1)
    from group_members gm join groups g on g.id=gm.group_id
   where gm.user_id=auth.uid()
   order by g.last_activity_at desc
   limit greatest(1,least(p_limit,100));
$$;

create or replace function public.get_recommended_groups(p_limit int default 20)
returns table(
  id uuid,name text,slug text,description text,category text,avatar_url text,privacy text,verified boolean,member_count integer,host_count integer,last_activity_at timestamptz,score numeric
) language sql stable security definer set search_path = public
as $$
  select g.id,g.name,g.slug,g.description,g.category,g.avatar_url,g.privacy,g.verified,g.member_count,g.host_count,g.last_activity_at,
         (least(g.member_count,1000)::numeric / 100.0) + (extract(epoch from now()-g.last_activity_at) * -0.00001) + (case when g.verified then 10 else 0 end)
    from groups g
   where g.privacy='public' and not exists(select 1 from group_members gm where gm.group_id=g.id and gm.user_id=auth.uid())
   order by score desc, g.last_activity_at desc
   limit greatest(1,least(p_limit,100));
$$;

create or replace function public.create_group_poll(
  p_group_id uuid,p_question text,p_options text[],p_multiple_choice boolean default false,p_anonymous boolean default false,p_closes_at timestamptz default null
)
returns uuid language plpgsql security definer set search_path = public
as $$
declare pid uuid; i integer; label text;
begin
  if not is_group_staff(p_group_id) then raise exception 'Only group staff can create polls'; end if;
  if coalesce(array_length(p_options,1),0) < 2 or array_length(p_options,1) > 8 then raise exception 'Polls need 2 to 8 options'; end if;
  insert into group_polls(group_id,creator_id,question,multiple_choice,anonymous,closes_at) values(p_group_id,auth.uid(),trim(p_question),p_multiple_choice,p_anonymous,p_closes_at) returning id into pid;
  for i in 1..array_length(p_options,1) loop
    label := trim(p_options[i]);
    if char_length(label)=0 then raise exception 'Poll options cannot be empty'; end if;
    insert into group_poll_options(poll_id,label,position) values(pid,label,i);
  end loop;
  insert into group_events(group_id,actor_id,event_type) values(p_group_id,auth.uid(),'message');
  return pid;
end;
$$;

-- Realtime is used directly by Flutter for chat updates.
do $$
begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='group_messages') then
    alter publication supabase_realtime add table public.group_messages;
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='group_message_reactions') then
    alter publication supabase_realtime add table public.group_message_reactions;
  end if;
end $$;
-- FUSKAMO Groups v2: rules, durable staff pins, and invite acceptance.
-- Run after 016_groups.sql.

alter table public.groups
  add column if not exists rules text not null default '' check (char_length(rules) <= 5000);

create unique index if not exists ux_group_pins_message on public.group_pins(message_id) where message_id is not null;
create unique index if not exists ux_group_pins_poll on public.group_pins(poll_id) where poll_id is not null;
create index if not exists idx_group_pins_group_created on public.group_pins(group_id, created_at desc);
create index if not exists idx_group_invites_group_active on public.group_invites(group_id, active, created_at desc);

-- Staff can pin/unpin old or new content at any time. The operation is
-- transactional and updates the denormalized message flag as well.
create or replace function public.pin_group_message(p_message_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare gid uuid;
begin
  select group_id into gid from group_messages where id = p_message_id;
  if gid is null then raise exception 'Message not found'; end if;
  if not is_group_staff(gid) then raise exception 'Only group staff can pin messages'; end if;
  insert into group_pins(group_id,message_id,pinned_by)
  values(gid,p_message_id,auth.uid())
  on conflict (message_id) where message_id is not null do nothing;
  update group_messages set is_pinned = true where id = p_message_id;
end;
$$;

create or replace function public.unpin_group_message(p_message_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare gid uuid;
begin
  select group_id into gid from group_messages where id = p_message_id;
  if gid is null then raise exception 'Message not found'; end if;
  if not is_group_staff(gid) then raise exception 'Only group staff can unpin messages'; end if;
  delete from group_pins where message_id = p_message_id;
  update group_messages set is_pinned = false where id = p_message_id;
end;
$$;

create or replace function public.pin_group_poll(p_poll_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare gid uuid;
begin
  select group_id into gid from group_polls where id = p_poll_id;
  if gid is null then raise exception 'Poll not found'; end if;
  if not is_group_staff(gid) then raise exception 'Only group staff can pin polls'; end if;
  insert into group_pins(group_id,poll_id,pinned_by)
  values(gid,p_poll_id,auth.uid())
  on conflict (poll_id) where poll_id is not null do nothing;
end;
$$;

create or replace function public.unpin_group_poll(p_poll_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare gid uuid;
begin
  select group_id into gid from group_polls where id = p_poll_id;
  if gid is null then raise exception 'Poll not found'; end if;
  if not is_group_staff(gid) then raise exception 'Only group staff can unpin polls'; end if;
  delete from group_pins where poll_id = p_poll_id;
end;
$$;

create or replace function public.create_group_invite(
  p_group_id uuid,
  p_expires_at timestamptz default null,
  p_max_uses integer default null
)
returns text language plpgsql security definer set search_path = public
as $$
declare code text;
begin
  if not is_group_staff(p_group_id) then raise exception 'Only group staff can create invites'; end if;
  if exists(select 1 from groups where id=p_group_id and privacy <> 'secret') then
    -- Invites are useful for every privacy level, including public groups.
    null;
  end if;
  code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into group_invites(group_id,code,created_by,expires_at,max_uses)
  values(p_group_id,code,auth.uid(),p_expires_at,p_max_uses);
  return code;
end;
$$;

create or replace function public.accept_group_invite(p_code text, p_display_name text default 'Member')
returns text language plpgsql security definer set search_path = public
as $$
declare inv group_invites; g groups;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into inv from group_invites where code = upper(trim(p_code)) and active = true for update;
  if inv.id is null then raise exception 'Invite is invalid or inactive'; end if;
  if inv.expires_at is not null and inv.expires_at < now() then raise exception 'Invite has expired'; end if;
  if inv.max_uses is not null and inv.uses >= inv.max_uses then raise exception 'Invite has reached its use limit'; end if;
  select * into g from groups where id = inv.group_id;
  if g.id is null then raise exception 'Group not found'; end if;
  if exists(select 1 from group_members where group_id=g.id and user_id=auth.uid()) then return 'already_member'; end if;
  insert into group_members(group_id,user_id,role,display_name)
  values(g.id,auth.uid(),'member',coalesce(nullif(trim(p_display_name),''),'Member'));
  update group_invites set uses=uses+1, active=case when max_uses is not null and uses+1 >= max_uses then false else active end where id=inv.id;
  insert into group_events(group_id,actor_id,event_type) values(g.id,auth.uid(),'join');
  return g.id::text;
end;
$$;

-- Public-safe preview for invite acceptance. It exposes only the information
-- required to show the user what they are about to join.
create or replace function public.preview_group_invite(p_code text)
returns table(group_id uuid,name text,description text,rules text,privacy text,avatar_url text,member_count integer,host_count integer,verified boolean)
language sql stable security definer set search_path = public
as $$
  select g.id,g.name,g.description,g.rules,g.privacy,g.avatar_url,g.member_count,g.host_count,g.verified
  from group_invites i join groups g on g.id=i.group_id
  where i.code=upper(trim(p_code)) and i.active=true
    and (i.expires_at is null or i.expires_at > now())
    and (i.max_uses is null or i.uses < i.max_uses)
  limit 1;
$$;

-- Ensure newly-created groups return their rules to the UI.
-- Existing 016 RPCs remain compatible; Flutter fetches rules directly when
-- opening a recommended group.

create or replace function public.create_group(
  p_name text,
  p_slug text,
  p_description text,
  p_category text,
  p_privacy text,
  p_avatar_url text default null,
  p_join_approval boolean default false,
  p_allow_member_invites boolean default true,
  p_allow_member_mentions boolean default true,
  p_display_name text default 'Host',
  p_rules text default ''
)
returns groups language plpgsql security definer set search_path = public
as $$
declare g groups;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_privacy not in ('public','private','secret') then raise exception 'Invalid privacy'; end if;
  insert into groups(owner_id,name,slug,description,category,privacy,avatar_url,join_approval,allow_member_invites,allow_member_mentions,rules)
  values(auth.uid(),trim(p_name),lower(trim(p_slug)),coalesce(p_description,''),coalesce(nullif(trim(p_category),''),'General Football'),p_privacy,p_avatar_url,p_join_approval,p_allow_member_invites,p_allow_member_mentions,left(coalesce(p_rules,''),5000))
  returning * into g;
  insert into group_members(group_id,user_id,role,display_name) values(g.id,auth.uid(),'owner',coalesce(nullif(trim(p_display_name),''),'Host'));
  return g;
end;
$$;

create or replace function public.create_group_invite(
  p_group_id uuid,
  p_expires_at timestamptz default null,
  p_max_uses integer default null
)
returns text language plpgsql security definer set search_path = public
as $$
declare code text; can_invite boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select (is_group_staff(p_group_id) or (allow_member_invites and is_group_member(p_group_id))) into can_invite from groups where id=p_group_id;
  if coalesce(can_invite,false) = false then raise exception 'You are not allowed to invite people to this group'; end if;
  if p_max_uses is not null and p_max_uses < 1 then raise exception 'Maximum uses must be at least 1'; end if;
  code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
  insert into group_invites(group_id,code,created_by,expires_at,max_uses)
  values(p_group_id,code,auth.uid(),p_expires_at,p_max_uses);
  return code;
end;
$$;
-- FUSKAMO identity + direct messaging + verification badges.
-- Badge colour is an administrative trust signal, never self-verifiable.

create table if not exists profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'FUSKAMO Member' check (char_length(trim(display_name)) between 1 and 80),
  username text unique check (username is null or username ~ '^[a-zA-Z0-9_.-]{3,30}$'),
  bio text not null default '' check (char_length(bio) <= 500),
  avatar_url text,
  website text,
  instagram text,
  x_handle text,
  tiktok text,
  snapchat text,
  bluesky text,
  role text not null default 'player' check (role in ('player','scout','coach','club','fan','admin')),
  verified boolean not null default false,
  badge_type text not null default 'none' check (badge_type in ('none','gold','blue','black')),
  message_requests text not null default 'everyone' check (message_requests in ('everyone','followers','nobody')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_username on profiles(username);
create index if not exists idx_profiles_role_verified on profiles(role, verified, updated_at desc);

alter table profiles enable row level security;

create policy "Profiles are publicly readable"
  on profiles for select using (true);

create policy "Users can create their own profile"
  on profiles for insert with check (auth.uid() = user_id and verified = false and badge_type = 'none');

create policy "Users can update their own public profile"
  on profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and verified = false and badge_type = 'none');

-- Keep the public profile in sync with Supabase Auth metadata when the app
-- first opens. This function intentionally cannot grant verification.
create or replace function ensure_my_profile(
  p_display_name text default null,
  p_username text default null,
  p_bio text default null,
  p_avatar_url text default null,
  p_website text default null,
  p_instagram text default null,
  p_x_handle text default null,
  p_tiktok text default null,
  p_snapchat text default null,
  p_bluesky text default null,
  p_role text default 'player'
)
returns profiles
language plpgsql
security definer
set search_path = public
as $$
declare r profiles;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_role not in ('player','scout','coach','club','fan') then p_role := 'fan'; end if;
  if p_role = 'player' and exists(select 1 from scouts where user_id = auth.uid() and verified = true) then p_role := 'scout'; end if;

  insert into profiles(user_id, display_name, username, bio, avatar_url, website, instagram, x_handle, tiktok, snapchat, bluesky, role, verified, badge_type)
  values (
    auth.uid(),
    coalesce(nullif(trim(p_display_name), ''), 'FUSKAMO Member'),
    nullif(trim(p_username), ''),
    coalesce(p_bio, ''), p_avatar_url, p_website, p_instagram, p_x_handle, p_tiktok, p_snapchat, p_bluesky, p_role,
    (p_role = 'scout' and exists(select 1 from scouts where user_id = auth.uid() and verified = true))
      or (p_role = 'player' and exists(select 1 from players where submitted_by = auth.uid() and status = 'approved')),
    case when p_role = 'scout' then 'blue' when p_role in ('player','coach') then 'black' when p_role = 'club' then 'gold' else 'none' end
  )
  on conflict (user_id) do update set
    display_name = coalesce(nullif(trim(p_display_name), ''), profiles.display_name),
    username = coalesce(nullif(trim(p_username), ''), profiles.username),
    bio = coalesce(p_bio, profiles.bio),
    avatar_url = coalesce(p_avatar_url, profiles.avatar_url),
    website = coalesce(p_website, profiles.website),
    instagram = coalesce(p_instagram, profiles.instagram),
    x_handle = coalesce(p_x_handle, profiles.x_handle),
    tiktok = coalesce(p_tiktok, profiles.tiktok),
    snapchat = coalesce(p_snapchat, profiles.snapchat),
    bluesky = coalesce(p_bluesky, profiles.bluesky),
    role = case when profiles.verified then profiles.role else p_role end,
    verified = case
      when profiles.verified then true
      when p_role = 'scout' and exists(select 1 from scouts where user_id = auth.uid() and verified = true) then true
      when p_role = 'player' and exists(select 1 from players where submitted_by = auth.uid() and status = 'approved') then true
      else false
    end,
    badge_type = case
      when profiles.verified then profiles.badge_type
      when p_role = 'scout' and exists(select 1 from scouts where user_id = auth.uid() and verified = true) then 'blue'
      when p_role = 'club' then 'gold'
      when p_role in ('player','coach') then 'black'
      else 'none'
    end,
    updated_at = now()
  returning * into r;
  return r;
end;
$$;

grant execute on function ensure_my_profile(text,text,text,text,text,text,text,text,text,text,text) to authenticated;

create table if not exists direct_conversations (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz
);

create table if not exists direct_conversation_participants (
  conversation_id uuid not null references direct_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  muted boolean not null default false,
  primary key(conversation_id, user_id)
);

create table if not exists direct_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references direct_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  reply_to_id uuid references direct_messages(id) on delete set null,
  edited_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_dcp_user_updated on direct_conversation_participants(user_id, last_read_at desc);
create index if not exists idx_dm_conversation_created on direct_messages(conversation_id, created_at desc);
create index if not exists idx_dm_sender_created on direct_messages(sender_id, created_at desc);

create table if not exists user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);

alter table direct_conversations enable row level security;
alter table direct_conversation_participants enable row level security;
alter table direct_messages enable row level security;
alter table user_blocks enable row level security;

create policy "Participants can view conversations"
  on direct_conversations for select
  using (exists(select 1 from direct_conversation_participants p where p.conversation_id = id and p.user_id = auth.uid()));

create policy "Participants can view participants"
  on direct_conversation_participants for select
  using (exists(select 1 from direct_conversation_participants p where p.conversation_id = conversation_id and p.user_id = auth.uid()));

create policy "Participants can view messages"
  on direct_messages for select
  using (exists(select 1 from direct_conversation_participants p where p.conversation_id = direct_messages.conversation_id and p.user_id = auth.uid()));

create policy "Participants can send messages"
  on direct_messages for insert
  with check (
    sender_id = auth.uid() and
    exists(select 1 from direct_conversation_participants p where p.conversation_id = direct_messages.conversation_id and p.user_id = auth.uid())
  );

create policy "Senders can edit their messages"
  on direct_messages for update
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

create policy "Users can read their blocks"
  on user_blocks for select using (blocker_id = auth.uid());
create policy "Users can create their blocks"
  on user_blocks for insert with check (blocker_id = auth.uid());
create policy "Users can remove their blocks"
  on user_blocks for delete using (blocker_id = auth.uid());

-- One canonical 1-to-1 conversation per pair. The function also enforces
-- message-request preferences and blocks before creating anything.
create or replace function get_or_create_direct_conversation(p_other_user uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  mine uuid := auth.uid();
  conversation_id uuid;
  pref text;
begin
  if mine is null then raise exception 'Authentication required'; end if;
  if p_other_user is null or p_other_user = mine then raise exception 'Invalid recipient'; end if;

  if exists(select 1 from user_blocks where blocker_id = mine and blocked_id = p_other_user)
     or exists(select 1 from user_blocks where blocker_id = p_other_user and blocked_id = mine) then
    raise exception 'Messaging is unavailable between these accounts';
  end if;

  select message_requests into pref from profiles where user_id = p_other_user;
  if pref = 'nobody' then raise exception 'This account does not accept message requests'; end if;

  select p1.conversation_id into conversation_id
  from direct_conversation_participants p1
  join direct_conversation_participants p2 on p2.conversation_id = p1.conversation_id
  where p1.user_id = mine and p2.user_id = p_other_user
  group by p1.conversation_id
  having count(*) = 2
  limit 1;

  if conversation_id is null then
    insert into direct_conversations(created_by, updated_at) values(mine, now()) returning id into conversation_id;
    insert into direct_conversation_participants(conversation_id, user_id) values(conversation_id, mine), (conversation_id, p_other_user);
  end if;
  return conversation_id;
end;
$$;

grant execute on function get_or_create_direct_conversation(uuid) to authenticated;

create or replace function mark_direct_conversation_read(p_conversation uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update direct_conversation_participants
  set last_read_at = now()
  where conversation_id = p_conversation and user_id = auth.uid();
end;
$$;
grant execute on function mark_direct_conversation_read(uuid) to authenticated;

create or replace function update_direct_conversation_activity(p_conversation uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists(select 1 from direct_conversation_participants where conversation_id = p_conversation and user_id = auth.uid()) then
    raise exception 'Not a conversation participant';
  end if;
  update direct_conversations set updated_at = now(), last_message_at = now() where id = p_conversation;
end;
$$;
grant execute on function update_direct_conversation_activity(uuid) to authenticated;

-- Realtime for instant DM delivery.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'direct_messages') then
    alter publication supabase_realtime add table direct_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'direct_conversation_participants') then
    alter publication supabase_realtime add table direct_conversation_participants;
  end if;
end $$;
-- FUSKAMO TRUST + AWARD ENGINE
-- Verification is earned through evidence and review, never purchased.
-- Achievements are separate from verification and cannot be exchanged for a tick.

alter table profiles
  add column if not exists verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','rejected','revoked')),
  add column if not exists trust_score numeric(5,2) not null default 0 check (trust_score between 0 and 100),
  add column if not exists profile_completion numeric(5,2) not null default 0 check (profile_completion between 0 and 100),
  add column if not exists identity_claim text,
  add column if not exists affiliation_notice text,
  add column if not exists verification_method text,
  add column if not exists verification_reason text,
  add column if not exists verified_at timestamptz,
  add column if not exists verification_expires_at timestamptz;

create table if not exists verification_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  applicant_role text not null check (applicant_role in ('club','scout','coach','player')),
  claimed_name text not null check (char_length(trim(claimed_name)) between 2 and 160),
  organization_name text,
  country text,
  official_website text,
  official_email text,
  official_domain text,
  registration_number text,
  governing_body text,
  professional_license text,
  evidence_urls text[] not null default '{}',
  social_links text[] not null default '{}',
  identity_document_ref text,
  organization_document_ref text,
  declaration_accepted boolean not null default false,
  legal_notice_version text not null default '2026-08-15',
  status text not null default 'pending' check (status in ('pending','needs_more_info','approved','rejected','revoked')),
  risk_score numeric(5,2) not null default 0 check (risk_score between 0 and 100),
  review_notes text,
  rejection_reason text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);
create index if not exists idx_verification_apps_status on verification_applications(status, submitted_at desc);
create index if not exists idx_verification_apps_user on verification_applications(user_id, submitted_at desc);

create table if not exists verification_domain_challenges (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references verification_applications(id) on delete cascade,
  domain text not null,
  token text not null unique,
  method text not null default 'dns_txt' check (method in ('dns_txt','website_file','official_email')),
  verified_at timestamptz,
  expires_at timestamptz not null default now() + interval '7 days',
  created_at timestamptz not null default now()
);
create index if not exists idx_domain_challenges_app on verification_domain_challenges(application_id, expires_at desc);

create table if not exists badge_achievements (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name text not null,
  description text not null,
  icon text not null default '★',
  points integer not null default 0 check (points between 0 and 1000),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists profile_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid not null references badge_achievements(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  awarded_reason text,
  source text not null default 'system' check (source in ('system','admin','community')),
  primary key(user_id, achievement_id)
);
create index if not exists idx_profile_achievements_user on profile_achievements(user_id, awarded_at desc);

create table if not exists profile_likes (
  user_id uuid not null references auth.users(id) on delete cascade,
  liker_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, liker_id),
  check(user_id <> liker_id)
);
create index if not exists idx_profile_likes_user on profile_likes(user_id, created_at desc);

create table if not exists verification_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  application_id uuid references verification_applications(id) on delete set null,
  event_type text not null,
  old_status text,
  new_status text,
  old_badge text,
  new_badge text,
  actor_id uuid references auth.users(id),
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_verification_events_user on verification_events(user_id, created_at desc);

alter table verification_applications enable row level security;
alter table verification_domain_challenges enable row level security;
alter table badge_achievements enable row level security;
alter table profile_achievements enable row level security;
alter table profile_likes enable row level security;
alter table verification_events enable row level security;

create policy "Users can view their verification applications"
 on verification_applications for select using (auth.uid() = user_id);
create policy "Users can submit their verification applications"
 on verification_applications for insert with check (auth.uid() = user_id and declaration_accepted = true and status = 'pending');
create policy "Users can update their own pending applications"
 on verification_applications for update using (auth.uid() = user_id and status in ('pending','needs_more_info'))
 with check (auth.uid() = user_id and status in ('pending','needs_more_info'));
create policy "Users can view their domain challenges"
 on verification_domain_challenges for select using (
   exists(select 1 from verification_applications a where a.id = application_id and a.user_id = auth.uid())
 );
create policy "Active achievements are public"
 on badge_achievements for select using (active = true);
create policy "Awarded achievements are public"
 on profile_achievements for select using (true);
create policy "Users can view profile likes"
 on profile_likes for select using (true);
create policy "Users can like profiles"
 on profile_likes for insert with check (liker_id = auth.uid());
create policy "Users can remove their profile likes"
 on profile_likes for delete using (liker_id = auth.uid());
create policy "Users can view their verification events"
 on verification_events for select using (user_id = auth.uid());

-- Seed achievements. These are recognition signals, not verification substitutes.
insert into badge_achievements(code,name,description,icon,points) values
 ('profile_complete','Complete Profile','Completed the public profile with consistent information.','✓',10),
 ('community_rising','Community Rising','Built meaningful positive engagement on FUSKAMO.','↗',15),
 ('well_known','Well Known','Reached a sustained level of authentic profile recognition.','★',25),
 ('trusted_contributor','Trusted Contributor','Maintained strong participation without repeated moderation violations.','◆',30),
 ('verified_application','Verification Applicant','Submitted a complete verification application for review.','◈',5),
 ('club_confirmed','Club Confirmed','Club identity was independently verified by FUSKAMO review.','■',50),
 ('scout_confirmed','Scout Confirmed','Scout identity and professional standing were independently verified.','●',50),
 ('coach_confirmed','Coach Confirmed','Coach identity and credentials were independently verified.','▲',50),
 ('player_confirmed','Player Confirmed','Player identity/profile was approved through the player review process.','◆',40)
on conflict(code) do nothing;

-- Profile scoring: profile appearance matters, but popularity can never directly create a tick.
create or replace function calculate_profile_trust(p_user uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  p profiles;
  score numeric := 0;
  likes_count integer := 0;
  positive_achievements integer := 0;
begin
  select * into p from profiles where user_id = p_user;
  if not found then return 0; end if;

  score := score + case when nullif(trim(p.display_name),'') is not null then 10 else 0 end;
  score := score + case when nullif(trim(p.username),'') is not null then 8 else 0 end;
  score := score + case when char_length(trim(p.bio)) >= 30 then 8 else 0 end;
  score := score + case when nullif(trim(p.avatar_url),'') is not null then 8 else 0 end;
  score := score + case when nullif(trim(p.website),'') is not null then 6 else 0 end;
  score := score + case when nullif(trim(p.instagram),'') is not null or nullif(trim(p.x_handle),'') is not null or nullif(trim(p.tiktok),'') is not null then 5 else 0 end;
  score := score + case when p.role in ('club','scout','coach') then 5 else 2 end;

  select count(*) into likes_count from profile_likes where user_id = p_user;
  score := score + least(20, floor(ln(greatest(likes_count,0) + 1) * 6));

  select count(*) into positive_achievements from profile_achievements where user_id = p_user;
  score := score + least(20, positive_achievements * 3);

  return least(100, round(score,2));
end;
$$;
grant execute on function calculate_profile_trust(uuid) to authenticated;

create or replace function refresh_my_trust_score()
returns profiles
language plpgsql
security definer
set search_path = public
as $$
declare r profiles; s numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 s := calculate_profile_trust(auth.uid());
 update profiles set trust_score=s, profile_completion=least(100, s), updated_at=now() where user_id=auth.uid() returning * into r;
 return r;
end;
$$;
grant execute on function refresh_my_trust_score() to authenticated;

-- Like-based achievements require thresholds and do NOT verify anyone.
create or replace function refresh_my_achievements()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  n integer := 0;
  likes_count integer;
  score numeric;
  ach uuid;
begin
  if uid is null then raise exception 'Authentication required'; end if;
  score := calculate_profile_trust(uid);
  select count(*) into likes_count from profile_likes where user_id = uid;

  if score >= 30 then
    select id into ach from badge_achievements where code='profile_complete';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Profile reached the completeness threshold') on conflict do nothing;
  end if;
  if likes_count >= 25 then
    select id into ach from badge_achievements where code='community_rising';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Reached 25 authentic profile likes') on conflict do nothing;
  end if;
  if likes_count >= 250 then
    select id into ach from badge_achievements where code='well_known';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Reached 250 authentic profile likes') on conflict do nothing;
  end if;
  return n;
end;
$$;
grant execute on function refresh_my_achievements() to authenticated;

-- Submit a verification request. The system assigns pending status and never grants a tick.
create or replace function submit_verification_application(
  p_role text,
  p_claimed_name text,
  p_organization_name text default null,
  p_country text default null,
  p_official_website text default null,
  p_official_email text default null,
  p_official_domain text default null,
  p_registration_number text default null,
  p_governing_body text default null,
  p_professional_license text default null,
  p_evidence_urls text[] default '{}',
  p_social_links text[] default '{}',
  p_identity_document_ref text default null,
  p_organization_document_ref text default null
)
returns verification_applications
language plpgsql
security definer
set search_path = public
as $$
declare r verification_applications;
uid uuid := auth.uid();
begin
 if uid is null then raise exception 'Authentication required'; end if;
 if p_role not in ('club','scout','coach','player') then raise exception 'Verification is available to clubs, scouts, coaches and players'; end if;
 if p_claimed_name is null or char_length(trim(p_claimed_name)) < 2 then raise exception 'Claimed name is required'; end if;
 if exists(select 1 from verification_applications where user_id=uid and status in ('pending','needs_more_info')) then raise exception 'You already have an application under review'; end if;
 insert into verification_applications(user_id,applicant_role,claimed_name,organization_name,country,official_website,official_email,official_domain,registration_number,governing_body,professional_license,evidence_urls,social_links,identity_document_ref,organization_document_ref,declaration_accepted)
 values(uid,p_role,trim(p_claimed_name),nullif(trim(p_organization_name),''),nullif(trim(p_country),''),nullif(trim(p_official_website),''),nullif(trim(p_official_email),''),nullif(lower(trim(p_official_domain)),''),nullif(trim(p_registration_number),''),nullif(trim(p_governing_body),''),nullif(trim(p_professional_license),''),coalesce(p_evidence_urls,'{}'),coalesce(p_social_links,'{}'),p_identity_document_ref,p_organization_document_ref,true)
 returning * into r;
 update profiles set verification_status='pending', updated_at=now() where user_id=uid;
 insert into verification_events(user_id,application_id,event_type,new_status,reason) values(uid,r.id,'application_submitted','pending','Applicant submitted an identity/organization verification request');
 return r;
end;
$$;
grant execute on function submit_verification_application(text,text,text,text,text,text,text,text,text,text,text[],text[],text,text) to authenticated;

-- Admin review functions. They are executable only by admins with verification:manage permission through the backend route.
create or replace function review_verification_application(
  p_application uuid,
  p_decision text,
  p_reason text default null,
  p_method text default 'manual_review'
)
returns verification_applications
language plpgsql
security definer
set search_path = public
as $$
declare a verification_applications; r profiles; old_badge text; new_badge text;
begin
 if p_decision not in ('approved','rejected','needs_more_info','revoked') then raise exception 'Invalid decision'; end if;
 select * into a from verification_applications where id=p_application for update;
 if not found then raise exception 'Application not found'; end if;
 select badge_type into old_badge from profiles where user_id=a.user_id;
 update verification_applications set status=p_decision, review_notes=case when p_decision='needs_more_info' then p_reason else review_notes end, rejection_reason=case when p_decision in ('rejected','revoked') then p_reason else null end, reviewed_at=now(), reviewed_by=auth.uid(), updated_at=now() where id=p_application returning * into a;
 new_badge := case a.applicant_role when 'club' then 'gold' when 'scout' then 'blue' when 'player' then 'black' when 'coach' then 'black' end;
 update profiles set
   verified = (p_decision='approved'),
   badge_type = case when p_decision='approved' then new_badge else 'none' end,
   verification_status = p_decision,
   verification_method = case when p_decision='approved' then p_method else null end,
   verification_reason = p_reason,
   verified_at = case when p_decision='approved' then now() else null end,
   verification_expires_at = case when p_decision='approved' then now() + interval '365 days' else null end,
   updated_at=now()
 where user_id=a.user_id returning * into r;
 insert into verification_events(user_id,application_id,event_type,old_status,new_status,old_badge,new_badge,actor_id,reason)
 values(a.user_id,a.id,'admin_review',null,p_decision,old_badge,r.badge_type,auth.uid(),p_reason);
 if p_decision='approved' then
   insert into profile_achievements(user_id,achievement_id,awarded_reason,source)
   select a.user_id,id, 'Identity/organization verification approved', 'admin' from badge_achievements where code=case a.applicant_role when 'club' then 'club_confirmed' when 'scout' then 'scout_confirmed' when 'coach' then 'coach_confirmed' else 'player_confirmed' end
   on conflict do nothing;
 end if;
 return a;
end;
$$;

-- Prevent ordinary users from changing trust/verification fields through direct updates.
create or replace function protect_profile_trust_fields()
returns trigger
language plpgsql
as $$
begin
 if auth.uid() = old.user_id then
   new.verified := old.verified;
   new.badge_type := old.badge_type;
   new.verification_status := old.verification_status;
   new.trust_score := old.trust_score;
   new.profile_completion := old.profile_completion;
   new.verification_method := old.verification_method;
   new.verification_reason := old.verification_reason;
   new.verified_at := old.verified_at;
   new.verification_expires_at := old.verification_expires_at;
 end if;
 return new;
end;
$$;
drop trigger if exists trg_protect_profile_trust on profiles;
create trigger trg_protect_profile_trust before update on profiles for each row execute function protect_profile_trust_fields();

-- Public function for a clean non-affiliation banner when a profile claims an organization/person but is not verified.
create or replace function get_affiliation_notice(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p.affiliation_notice is not null then p.affiliation_notice
    when p.identity_claim is not null and p.verified = false then 'Not affiliated with ' || p.identity_claim || ' unless this profile displays a FUSKAMO verification badge.'
    else null
  end from profiles p where p.user_id=p_user;
$$;
grant execute on function get_affiliation_notice(uuid) to anon, authenticated;

-- Keep profile verification state coherent when an approved player/scout already exists.
update profiles p set
  verified = true,
  verification_status='verified',
  badge_type = case when p.role='scout' then 'blue' when p.role in ('player','coach') then 'black' when p.role='club' then 'gold' else p.badge_type end,
  verified_at=coalesce(p.verified_at,now())
where p.role='scout' and exists(select 1 from scouts s where s.user_id=p.user_id and s.verified=true);

create or replace function set_identity_claim(p_identity_claim text)
returns profiles
language plpgsql
security definer
set search_path = public
as $$
declare r profiles;
uid uuid := auth.uid();
clean text := nullif(trim(p_identity_claim),'');
begin
 if uid is null then raise exception 'Authentication required'; end if;
 update profiles set
   identity_claim = clean,
   affiliation_notice = case when clean is null then null else case when verified then null else 'Not affiliated with ' || clean || ' unless this profile displays a FUSKAMO verification badge.' end end,
   updated_at=now()
 where user_id=uid returning * into r;
 return r;
end;
$$;
grant execute on function set_identity_claim(text) to authenticated;

-- Recompute non-verification trust signals when engagement changes.
create or replace function on_profile_like_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target uuid;
begin
 target := coalesce(new.user_id, old.user_id);
 update profiles set trust_score=calculate_profile_trust(target), profile_completion=least(100,calculate_profile_trust(target)), updated_at=now() where user_id=target;
 return coalesce(new,old);
end;
$$;
drop trigger if exists trg_profile_like_trust on profile_likes;
create trigger trg_profile_like_trust after insert or delete on profile_likes for each row execute function on_profile_like_changed();

-- Verified endorsements are stronger than raw popularity and are never sold.
create table if not exists profile_endorsements (
  target_user_id uuid not null references auth.users(id) on delete cascade,
  endorser_user_id uuid not null references auth.users(id) on delete cascade,
  note text not null check (char_length(trim(note)) between 10 and 500),
  created_at timestamptz not null default now(),
  primary key(target_user_id, endorser_user_id),
  check(target_user_id <> endorser_user_id)
);
create index if not exists idx_profile_endorsements_target on profile_endorsements(target_user_id, created_at desc);
alter table profile_endorsements enable row level security;
create policy "Public can read endorsements" on profile_endorsements for select using (true);
create policy "Verified accounts can endorse" on profile_endorsements for insert with check (
  endorser_user_id=auth.uid() and exists(select 1 from profiles where user_id=auth.uid() and verified=true)
);
create policy "Endorsers can remove endorsements" on profile_endorsements for delete using (endorser_user_id=auth.uid());

insert into badge_achievements(code,name,description,icon,points) values
 ('trusted_by_verified','Trusted by Verified Members','Received endorsements from five independently verified FUSKAMO members.','✓',40),
 ('official_presence','Official Presence','Completed an official-domain or organization evidence check during verification review.','⌂',35)
on conflict(code) do nothing;

create or replace function refresh_my_achievements()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  likes_count integer;
  verified_endorsements integer;
  score numeric;
  ach uuid;
  awarded integer := 0;
begin
  if uid is null then raise exception 'Authentication required'; end if;
  score := calculate_profile_trust(uid);
  select count(*) into likes_count from profile_likes where user_id = uid;
  select count(*) into verified_endorsements from profile_endorsements e join profiles p on p.user_id=e.endorser_user_id and p.verified=true where e.target_user_id=uid;

  if score >= 30 then
    select id into ach from badge_achievements where code='profile_complete';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Profile reached the completeness threshold') on conflict do nothing;
  end if;
  if likes_count >= 25 then
    select id into ach from badge_achievements where code='community_rising';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Reached 25 authentic profile likes') on conflict do nothing;
  end if;
  if likes_count >= 250 then
    select id into ach from badge_achievements where code='well_known';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Reached 250 authentic profile likes') on conflict do nothing;
  end if;
  if verified_endorsements >= 5 then
    select id into ach from badge_achievements where code='trusted_by_verified';
    insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Received five endorsements from verified members') on conflict do nothing;
  end if;
  return awarded;
end;
$$;
grant execute on function refresh_my_achievements() to authenticated;

-- Existing approved players/scouts can synchronize their role-specific badge,
-- but only because their underlying submission/application was already reviewed.
create or replace function sync_verified_role_badge()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid; role_name text; b text;
begin
 if TG_TABLE_NAME='players' then
   if new.status <> 'approved' or new.submitted_by is null then return new; end if;
   uid:=new.submitted_by; role_name:='player'; b:='black';
 elsif TG_TABLE_NAME='scouts' then
   if new.verified is not true or new.user_id is null then return new; end if;
   uid:=new.user_id; role_name:='scout'; b:='blue';
 else return new;
 end if;
 update profiles set role=role_name,verified=true,badge_type=b,verification_status='verified',verification_method='approved_role_review',verified_at=coalesce(verified_at,now()),verification_expires_at=coalesce(verification_expires_at,now()+interval '365 days'),affiliation_notice=null,updated_at=now() where user_id=uid and verification_status <> 'revoked' and ((role_name='player' and role in ('player','fan')) or (role_name='scout' and role in ('scout','fan')));
 return new;
end;
$$;
drop trigger if exists trg_sync_player_badge on players;
create trigger trg_sync_player_badge after insert or update of status on players for each row execute function sync_verified_role_badge();
drop trigger if exists trg_sync_scout_badge on scouts;
create trigger trg_sync_scout_badge after insert or update of verified on scouts for each row execute function sync_verified_role_badge();

-- Evidence-quality/risk signal for reviewers. This is a review aid, not an automatic approval decision.
create or replace function calculate_verification_risk(a verification_applications)
returns numeric
language plpgsql
stable
as $$
declare risk numeric := 100; email_domain text;
begin
 if nullif(trim(a.official_website),'') is not null then risk := risk - 10; end if;
 if nullif(trim(a.registration_number),'') is not null then risk := risk - 20; end if;
 if nullif(trim(a.governing_body),'') is not null then risk := risk - 10; end if;
 if coalesce(array_length(a.evidence_urls,1),0) >= 2 then risk := risk - 15; elsif coalesce(array_length(a.evidence_urls,1),0)=1 then risk := risk - 5; end if;
 if coalesce(array_length(a.social_links,1),0) >= 2 then risk := risk - 5; end if;
 if a.identity_document_ref is not null then risk := risk - 15; end if;
 if a.organization_document_ref is not null then risk := risk - 15; end if;
 if a.official_domain is not null and a.official_email is not null then
   email_domain := lower(split_part(a.official_email,'@',2));
   if email_domain = lower(a.official_domain) then risk := risk - 20; else risk := risk + 10; end if;
 end if;
 return greatest(0,least(100,risk));
end;
$$;

create or replace function prepare_verification_application()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
 new.risk_score := calculate_verification_risk(new);
 return new;
end;
$$;
drop trigger if exists trg_verification_risk on verification_applications;
create trigger trg_verification_risk before insert or update on verification_applications for each row execute function prepare_verification_application();

create or replace function create_domain_challenge_for_application()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
 if new.official_domain is not null and not exists(select 1 from verification_domain_challenges where application_id=new.id and domain=new.official_domain and verified_at is null and expires_at > now()) then
   insert into verification_domain_challenges(application_id,domain,token,method)
   values(new.id,lower(new.official_domain),substring(md5(random()::text || clock_timestamp()::text) from 1 for 32),'dns_txt');
 end if;
 return new;
end;
$$;
drop trigger if exists trg_create_domain_challenge on verification_applications;
create trigger trg_create_domain_challenge after insert on verification_applications for each row execute function create_domain_challenge_for_application();
-- FUSKAMO TRUST/BADGE ALGORITHM V2
-- Popularity can earn recognition. Evidence + human review earns verification.
-- Payment, boosts, followers and likes are NEVER direct badge-award conditions.

-- Separate profile appearance from trust. profile_completion is now a real
-- 0..100 completeness percentage instead of being a copy of trust_score.
create or replace function calculate_profile_completion(p_user uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare p profiles; raw numeric := 0;
begin
  select * into p from profiles where user_id=p_user;
  if not found then return 0; end if;
  raw := raw + case when nullif(trim(p.display_name),'') is not null then 10 else 0 end;
  raw := raw + case when nullif(trim(p.username),'') is not null then 8 else 0 end;
  raw := raw + case when char_length(trim(coalesce(p.bio,''))) >= 30 then 8 else 0 end;
  raw := raw + case when nullif(trim(p.avatar_url),'') is not null then 8 else 0 end;
  raw := raw + case when nullif(trim(p.website),'') is not null then 6 else 0 end;
  raw := raw + case when nullif(trim(p.instagram),'') is not null or nullif(trim(p.x_handle),'') is not null or nullif(trim(p.tiktok),'') is not null then 5 else 0 end;
  raw := raw + case when p.role in ('club','scout','coach') then 5 else 2 end;
  return round((raw / 50.0) * 100.0,2);
end;
$$;
grant execute on function calculate_profile_completion(uuid) to authenticated;

-- Trust is a discovery/reputation signal, NOT a verification gate.
-- 35% appearance, 20% authentic profile likes, 25% verified endorsements,
-- 10% safety, 10% role consistency. Verification achievements are excluded
-- so a tick cannot create more trust which then reinforces the same tick.
create or replace function calculate_profile_trust(p_user uuid)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  p profiles;
  completion numeric := 0;
  likes_count integer := 0;
  endorsement_count integer := 0;
  fraud numeric := 0;
  role_signal numeric := 100;
  recognition numeric := 0;
  endorsements numeric := 0;
  safety numeric := 100;
begin
  select * into p from profiles where user_id=p_user;
  if not found then return 0; end if;

  completion := calculate_profile_completion(p_user);
  select count(*) into likes_count from profile_likes where user_id=p_user;
  recognition := least(100, (ln(greatest(least(likes_count,250),0)+1) / ln(251.0)) * 100);

  select count(*) into endorsement_count
  from profile_endorsements e
  join profiles ep on ep.user_id=e.endorser_user_id and ep.verified=true
  where e.target_user_id=p_user;
  endorsements := least(100, (least(endorsement_count,5)::numeric / 5.0) * 100);

  -- Player fraud is stored on the player record. If an account has no player
  -- row there is no fraud penalty from this source.
  select coalesce(max(fraud_score),0) into fraud from players where submitted_by=p_user;
  safety := greatest(0, 100 - least(1, fraud) * 100);

  if p.role not in ('player','scout','coach','club','fan') then role_signal := 0; end if;

  return round(greatest(0, least(100,
    completion * 0.35 + recognition * 0.20 + endorsements * 0.25 + safety * 0.10 + role_signal * 0.10
  )),2);
end;
$$;
grant execute on function calculate_profile_trust(uuid) to authenticated;

create or replace function refresh_my_trust_score()
returns profiles
language plpgsql
security definer
set search_path = public
as $$
declare r profiles; s numeric; c numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 c := calculate_profile_completion(auth.uid());
 s := calculate_profile_trust(auth.uid());
 update profiles set trust_score=s, profile_completion=c, updated_at=now()
 where user_id=auth.uid() returning * into r;
 return r;
end;
$$;
grant execute on function refresh_my_trust_score() to authenticated;

-- Verification evidence score. This is a reviewer aid. It can recommend
-- that an application is strong enough to inspect, but it NEVER changes a
-- profile to verified by itself.
alter table verification_applications
  add column if not exists evidence_score numeric(5,2) not null default 0 check (evidence_score between 0 and 100),
  add column if not exists domain_verified boolean not null default false;

create or replace function calculate_verification_evidence_score(a verification_applications)
returns numeric
language plpgsql
stable
as $$
declare score numeric := 0;
begin
 if nullif(trim(a.claimed_name),'') is not null then score := score + 5; end if;
 if nullif(trim(a.country),'') is not null then score := score + 5; end if;
 if nullif(trim(a.official_website),'') is not null then score := score + 10; end if;
 if nullif(trim(a.official_email),'') is not null then score := score + 10; end if;
 if nullif(trim(a.official_domain),'') is not null then score := score + 5; end if;
 if a.domain_verified then score := score + 20; end if;
 if nullif(trim(a.registration_number),'') is not null then score := score + 15; end if;
 if nullif(trim(a.governing_body),'') is not null then score := score + 10; end if;
 if nullif(trim(a.professional_license),'') is not null then score := score + 10; end if;
 if a.identity_document_ref is not null then score := score + 10; end if;
 if a.organization_document_ref is not null then score := score + 10; end if;
 score := score + least(10, coalesce(array_length(a.evidence_urls,1),0) * 5);
 score := score + least(5, coalesce(array_length(a.social_links,1),0) * 2.5);
 return greatest(0,least(100,round(score,2)));
end;
$$;

create or replace function refresh_verification_evidence_score()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
 new.evidence_score := calculate_verification_evidence_score(new);
 return new;
end;
$$;
drop trigger if exists trg_verification_evidence_score on verification_applications;
create trigger trg_verification_evidence_score
before insert or update on verification_applications
for each row execute function refresh_verification_evidence_score();

-- When staff confirm the domain, recompute the evidence score. Domain control
-- is supporting evidence only; it never approves the application.
create or replace function mark_verification_domain_verified(p_application uuid)
returns verification_applications
language plpgsql
security definer
set search_path=public
as $$
declare a verification_applications; c verification_domain_challenges;
begin
 select * into a from verification_applications where id=p_application for update;
 if not found then raise exception 'Application not found'; end if;
 select * into c from verification_domain_challenges
 where application_id=p_application and verified_at is null and expires_at > now()
 order by created_at desc limit 1;
 if not found then raise exception 'No active domain challenge'; end if;
 update verification_domain_challenges set verified_at=now() where id=c.id;
 update verification_applications set domain_verified=true, updated_at=now() where id=p_application returning * into a;
 return a;
end;
$$;

-- Badge award invariant: only the reviewed verification application can set
-- verified/badge_type. Likes, achievements, profile appearance, M-Pesa and
-- discovery boosts remain strictly outside this function.
create or replace function award_verified_badge(
  p_application uuid,
  p_reason text,
  p_method text default 'human_review'
)
returns profiles
language plpgsql
security definer
set search_path=public
as $$
declare a verification_applications; r profiles; b text;
begin
 select * into a from verification_applications where id=p_application for update;
 if not found then raise exception 'Application not found'; end if;
 if a.status <> 'approved' then raise exception 'Only an approved application can receive a badge'; end if;
 if p_method not in ('human_review','human_review_domain','approved_role_review') then raise exception 'Invalid verification method'; end if;
 b := case a.applicant_role when 'club' then 'gold' when 'scout' then 'blue' when 'player' then 'black' when 'coach' then 'black' else 'none' end;
 if b='none' then raise exception 'Unsupported badge role'; end if;
 update profiles set
   verified=true,
   badge_type=b,
   verification_status='verified',
   verification_method=p_method,
   verification_reason=p_reason,
   verified_at=now(),
   verification_expires_at=now()+interval '365 days',
   affiliation_notice=null,
   updated_at=now()
 where user_id=a.user_id returning * into r;
 if not found then raise exception 'Profile not found'; end if;
 insert into verification_events(user_id,application_id,event_type,new_status,new_badge,actor_id,reason,metadata)
 values(a.user_id,a.id,'badge_awarded','verified',b,auth.uid(),p_reason,jsonb_build_object('evidence_score',a.evidence_score,'domain_verified',a.domain_verified,'method',p_method));
 return r;
end;
$$;

-- Keep non-verification awards automatic, but never let them mutate the tick.
create or replace function refresh_my_achievements()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare uid uuid := auth.uid(); likes_count integer; endorsements integer; completion numeric; ach uuid; awarded integer := 0;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 completion := calculate_profile_completion(uid);
 select count(*) into likes_count from profile_likes where user_id=uid;
 select count(*) into endorsements from profile_endorsements e join profiles ep on ep.user_id=e.endorser_user_id and ep.verified=true where e.target_user_id=uid;

 if completion >= 80 then
   select id into ach from badge_achievements where code='profile_complete';
   insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Public profile reached 80% completeness') on conflict do nothing;
 end if;
 if likes_count >= 25 then
   select id into ach from badge_achievements where code='community_rising';
   insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Reached 25 authentic profile likes') on conflict do nothing;
 end if;
 if likes_count >= 250 then
   select id into ach from badge_achievements where code='well_known';
   insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Reached 250 authentic profile likes') on conflict do nothing;
 end if;
 if endorsements >= 5 then
   select id into ach from badge_achievements where code='trusted_by_verified';
   insert into profile_achievements(user_id,achievement_id,awarded_reason) values(uid,ach,'Received five endorsements from verified members') on conflict do nothing;
 end if;
 return awarded;
end;
$$;
grant execute on function refresh_my_achievements() to authenticated;

-- Revoke stale badges automatically when the one-year review window expires.
create or replace function expire_verification_badges()
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare n integer;
begin
 update profiles
 set verified=false,badge_type='none',verification_status='unverified',verification_method=null,verification_reason='Verification expired; re-review required',verified_at=null,verification_expires_at=null,updated_at=now()
 where verified=true and verification_expires_at is not null and verification_expires_at <= now();
 get diagnostics n = row_count;
 return n;
end;
$$;
-- FUSKAMO Identity v3 + Follow Graph + Scoreboard.
-- Usernames are canonical handles, not display-name aliases.

alter table profiles
  add column if not exists username_changed_at timestamptz,
  add column if not exists username_change_count integer not null default 0 check (username_change_count >= 0),
  add column if not exists followers_count integer not null default 0 check (followers_count >= 0),
  add column if not exists following_count integer not null default 0 check (following_count >= 0),
  add column if not exists profile_likes_count integer not null default 0 check (profile_likes_count >= 0),
  add column if not exists achievement_points integer not null default 0 check (achievement_points >= 0),
  add column if not exists scoreboard_score numeric(6,2) not null default 0 check (scoreboard_score between 0 and 100),
  add column if not exists momentum_score numeric(6,2) not null default 0 check (momentum_score between 0 and 100),
  add column if not exists scoreboard_updated_at timestamptz;

-- Clean existing handles into the canonical format.
update profiles
set username = lower(regexp_replace(trim(username), '^@', ''))
where username is not null;

update profiles
set username = 'member_' || substr(replace(user_id::text,'-',''),1,8)
where username is null or trim(username) = '';

create table if not exists reserved_usernames (
  username text primary key,
  reason text not null default 'system'
);

insert into reserved_usernames(username,reason) values
('admin','system'),('administrator','system'),('api','system'),('auth','system'),('club','role'),('coach','role'),('fuskamo','brand'),('fuskamoofficial','brand'),
('help','system'),('moderator','role'),('mod','role'),('official','system'),('player','role'),('scout','role'),('security','system'),('staff','system'),
('support','system'),('system','system'),('verified','system'),('null','system'),('undefined','system'),('root','system'),('login','system'),('settings','system'),
('messages','system'),('groups','system'),('discover','system'),('scoreboard','system'),('feed','system'),('search','system'),('terms','system'),('privacy','system')
on conflict(username) do nothing;

create table if not exists username_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  old_username text,
  new_username text not null,
  changed_at timestamptz not null default now()
);
create index if not exists idx_username_history_user on username_history(user_id, changed_at desc);

-- Canonical username policy: 3-20 chars, lowercase letters/numbers/underscore,
-- starts with a letter, no double underscores, never a reserved route/role name.
create or replace function validate_and_track_username()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare u text;
begin
  u := lower(trim(coalesce(new.username,'')));
  u := regexp_replace(u, '^@', '');
  if u = '' then
    raise exception 'Username is required';
  end if;
  if u !~ '^[a-z][a-z0-9_]{2,19}$' then
    raise exception 'Username must be 3-20 characters, start with a letter, and use only lowercase letters, numbers, and underscores';
  end if;
  if u ~ '__' then
    raise exception 'Username cannot contain consecutive underscores';
  end if;
  if exists(select 1 from reserved_usernames where username=u) then
    raise exception 'That username is reserved';
  end if;

  if tg_op='UPDATE' and u <> old.username then
    if old.username_changed_at is not null and old.username_changed_at > now() - interval '30 days' then
      raise exception 'Username can only be changed once every 30 days';
    end if;
    insert into username_history(user_id,old_username,new_username) values(new.user_id,old.username,u);
    new.username_changed_at := now();
    new.username_change_count := old.username_change_count + 1;
  elsif tg_op='INSERT' then
    new.username_changed_at := coalesce(new.username_changed_at, now());
    new.username_change_count := coalesce(new.username_change_count, 0);
  end if;
  new.username := u;
  return new;
end;
$$;

drop trigger if exists trg_profiles_username_policy on profiles;
create trigger trg_profiles_username_policy
before insert or update of username on profiles
for each row execute function validate_and_track_username();

alter table profiles alter column username set not null;
create unique index if not exists uq_profiles_username_lower on profiles(lower(username));

-- Follow graph: one follow per pair, no self-follows.
create table if not exists profile_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower_id, followed_id),
  check(follower_id <> followed_id)
);
create index if not exists idx_profile_follows_followed on profile_follows(followed_id, created_at desc);
create index if not exists idx_profile_follows_follower on profile_follows(follower_id, created_at desc);
alter table profile_follows enable row level security;
create policy "Public can read follows" on profile_follows for select using (true);
create policy "Users can follow" on profile_follows for insert with check (follower_id=auth.uid());
create policy "Users can unfollow" on profile_follows for delete using (follower_id=auth.uid());

-- Engagement gate: only authenticated, email-confirmed users can create likes/follows;
-- blocked pairs cannot be used to manufacture reputation.
create or replace function validate_profile_engagement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare confirmed timestamptz;
begin
  select email_confirmed_at into confirmed from auth.users where id=auth.uid();
  if confirmed is null then raise exception 'Confirm your email before using reputation features'; end if;
  if new.user_id = new.liker_id then raise exception 'You cannot like your own profile'; end if;
  if exists(select 1 from user_blocks where blocker_id=new.liker_id and blocked_id=new.user_id)
     or exists(select 1 from user_blocks where blocker_id=new.user_id and blocked_id=new.liker_id) then
    raise exception 'Blocked accounts cannot exchange reputation signals';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profile_like_gate on profile_likes;
create trigger trg_profile_like_gate before insert on profile_likes for each row execute function validate_profile_engagement();

create or replace function validate_follow_engagement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare confirmed timestamptz;
begin
  select email_confirmed_at into confirmed from auth.users where id=auth.uid();
  if confirmed is null then raise exception 'Confirm your email before following accounts'; end if;
  if new.follower_id = new.followed_id then raise exception 'You cannot follow yourself'; end if;
  if exists(select 1 from user_blocks where blocker_id=new.follower_id and blocked_id=new.followed_id)
     or exists(select 1 from user_blocks where blocker_id=new.followed_id and blocked_id=new.follower_id) then
    raise exception 'Blocked accounts cannot follow each other';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profile_follow_gate on profile_follows;
create trigger trg_profile_follow_gate before insert on profile_follows for each row execute function validate_follow_engagement();


-- Replace the original profile bootstrap so an approved player/scout is NOT
-- silently converted into a verification tick. Approval and verification are
-- separate decisions. New accounts receive a canonical handle if none is supplied.
create or replace function ensure_my_profile(
  p_display_name text default null,
  p_username text default null,
  p_bio text default null,
  p_avatar_url text default null,
  p_website text default null,
  p_instagram text default null,
  p_x_handle text default null,
  p_tiktok text default null,
  p_snapchat text default null,
  p_bluesky text default null,
  p_role text default 'player'
)
returns profiles
language plpgsql
security definer
set search_path = public
as $$
declare r profiles; requested_role text; requested_username text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  requested_role := case when p_role in ('player','scout','coach','club','fan') then p_role else 'fan' end;
  requested_username := nullif(lower(regexp_replace(trim(coalesce(p_username,'')), '^@', '')), '');
  if requested_username is null then
    requested_username := 'member_' || substr(replace(auth.uid()::text,'-',''),1,8);
  end if;

  insert into profiles(user_id,display_name,username,bio,avatar_url,website,instagram,x_handle,tiktok,snapchat,bluesky,role,verified,badge_type)
  values(auth.uid(),coalesce(nullif(trim(p_display_name),''),'FUSKAMO Member'),requested_username,coalesce(p_bio,''),p_avatar_url,p_website,p_instagram,p_x_handle,p_tiktok,p_snapchat,p_bluesky,requested_role,false,'none')
  on conflict(user_id) do update set
    display_name=coalesce(nullif(trim(p_display_name),''),profiles.display_name),
    username=coalesce(requested_username,profiles.username),
    bio=coalesce(p_bio,profiles.bio),
    avatar_url=coalesce(p_avatar_url,profiles.avatar_url),
    website=coalesce(p_website,profiles.website),
    instagram=coalesce(p_instagram,profiles.instagram),
    x_handle=coalesce(p_x_handle,profiles.x_handle),
    tiktok=coalesce(p_tiktok,profiles.tiktok),
    snapchat=coalesce(p_snapchat,profiles.snapchat),
    bluesky=coalesce(p_bluesky,profiles.bluesky),
    role=case when profiles.verified then profiles.role else requested_role end,
    updated_at=now()
  returning * into r;
  perform refresh_profile_social_counts(auth.uid());
  perform refresh_profile_reputation(auth.uid());
  select * into r from profiles where user_id=auth.uid();
  return r;
end;
$$;
grant execute on function ensure_my_profile(text,text,text,text,text,text,text,text,text,text,text) to authenticated;

-- Cached counts keep profile cards cheap.
create or replace function refresh_profile_social_counts(p_user uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare l integer; f integer; fl integer; ap integer;
begin
 select count(*) into l from profile_likes where user_id=p_user;
 select count(*) into f from profile_follows where followed_id=p_user;
 select count(*) into fl from profile_follows where follower_id=p_user;
 select coalesce(sum(a.points),0)::integer into ap from profile_achievements pa join badge_achievements a on a.id=pa.achievement_id where pa.user_id=p_user;
 update profiles set profile_likes_count=l,followers_count=f,following_count=fl,achievement_points=ap,updated_at=now() where user_id=p_user;
end;
$$;

create or replace function on_profile_follow_changed()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
 perform refresh_profile_social_counts(coalesce(new.followed_id,old.followed_id));
 perform refresh_profile_social_counts(coalesce(new.follower_id,old.follower_id));
 return coalesce(new,old);
end;
$$;
drop trigger if exists trg_profile_follow_counts on profile_follows;
create trigger trg_profile_follow_counts after insert or delete on profile_follows for each row execute function on_profile_follow_changed();

-- Final FUSKAMO Scoreboard score. It borrows the useful ideas users expect from
-- large social platforms (recognition, momentum, consistency, trust) without
-- copying their ranking code or making a blue tick a popularity multiplier.
create or replace function calculate_fuskamo_score(p_user uuid)
returns numeric
language plpgsql
security definer
set search_path=public
as $$
declare p profiles; trust numeric:=0; likes integer:=0; followers integer:=0; achievements integer:=0; momentum integer:=0; quality numeric:=0; completeness numeric:=0; raw numeric:=0; fraud numeric:=0; safety_multiplier numeric:=1;
begin
 select * into p from profiles where user_id=p_user;
 if not found then return 0; end if;
 trust := coalesce(p.trust_score,0);
 completeness := coalesce(p.profile_completion,0);
 likes := coalesce(p.profile_likes_count,0);
 followers := coalesce(p.followers_count,0);
 achievements := coalesce(p.achievement_points,0);
 select count(*) into momentum from profile_likes where user_id=p_user and created_at >= now()-interval '7 days';
 select count(*) + coalesce((select count(*) from profile_follows where followed_id=p_user and created_at >= now()-interval '7 days'),0) into momentum from profile_likes where user_id=p_user and created_at >= now()-interval '7 days';

 if p.role='player' then
   select coalesce(max(quality_score),0)*100, coalesce(max(fraud_score),0) into quality,fraud from players where submitted_by=p_user and status='approved';
 elsif p.role='scout' then
   quality := case when p.verified then 100 else 55 end;
 elsif p.role='club' then
   quality := case when p.verified then 100 else 55 end;
 elsif p.role='coach' then
   quality := case when p.verified then 100 else 55 end;
 else
   quality := trust;
 end if;
 safety_multiplier := greatest(0.55,1 - least(1,coalesce(fraud,0))*0.45);
 raw := quality*0.30 + trust*0.20 + least(100,ln(likes+1)/ln(1001.0)*100)*0.15 + least(100,ln(followers+1)/ln(1001.0)*100)*0.10 + least(100,achievements)*0.10 + least(100,momentum/50.0*100)*0.10 + completeness*0.05;
 return round(greatest(0,least(100,raw*safety_multiplier)),2);
end;
$$;
grant execute on function calculate_fuskamo_score(uuid) to authenticated;

create or replace function refresh_my_scoreboard_score()
returns profiles
language plpgsql
security definer
set search_path=public
as $$
declare r profiles; s numeric; m numeric; likes7 integer; follows7 integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 s := calculate_fuskamo_score(auth.uid());
 select count(*) into likes7 from profile_likes where user_id=auth.uid() and created_at >= now()-interval '7 days';
 select count(*) into follows7 from profile_follows where followed_id=auth.uid() and created_at >= now()-interval '7 days';
 m := least(100,((likes7+follows7)::numeric/50)*100);
 update profiles set scoreboard_score=s,momentum_score=m,scoreboard_updated_at=now(),updated_at=now() where user_id=auth.uid() returning * into r;
 return r;
end;
$$;
grant execute on function refresh_my_scoreboard_score() to authenticated;

-- Scoreboard query: deterministic tie-breakers prevent rankings jumping randomly.
create or replace function get_fuskamo_scoreboard(p_category text default 'global', p_limit integer default 50)
returns table(
  rank bigint, user_id uuid, display_name text, username text, avatar_url text, role text,
  verified boolean, badge_type text, scoreboard_score numeric, momentum_score numeric,
  followers_count integer, profile_likes_count integer, achievement_points integer
)
language sql
security definer
set search_path=public
as $$
  with eligible as (
    select p.*
    from profiles p
    where p.role <> 'admin'
      and (p_category='global' or p.role=p_category or (p_category='rising' and p.momentum_score >= 1) or (p_category='trusted' and p.trust_score >= 70))
  ), ranked as (
    select row_number() over(order by scoreboard_score desc, trust_score desc, followers_count desc, user_id) as r, e.* from eligible e
  )
  select r as rank,user_id,display_name,username,avatar_url,role,verified,badge_type,scoreboard_score,momentum_score,followers_count,profile_likes_count,achievement_points
  from ranked order by r limit greatest(1,least(coalesce(p_limit,50),100));
$$;
grant execute on function get_fuskamo_scoreboard(text,integer) to authenticated;

-- Refresh the target score after reputation changes. These are capped, not viral,
-- and a tick itself never changes the score directly.
create or replace function refresh_target_score_after_engagement()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare target uuid;
begin
 target := case when tg_table_name='profile_likes' then coalesce(new.user_id,old.user_id) else coalesce(new.followed_id,old.followed_id) end;
 perform refresh_profile_social_counts(target);
 update profiles set scoreboard_score=calculate_fuskamo_score(target), scoreboard_updated_at=now() where user_id=target;
 return coalesce(new,old);
end;
$$;
drop trigger if exists trg_profile_like_scoreboard on profile_likes;
create trigger trg_profile_like_scoreboard after insert or delete on profile_likes for each row execute function refresh_target_score_after_engagement();
drop trigger if exists trg_profile_follow_scoreboard on profile_follows;
create trigger trg_profile_follow_scoreboard after insert or delete on profile_follows for each row execute function refresh_target_score_after_engagement();

-- Backfill scores for existing accounts.
do $$
declare r profiles;
begin
 for r in select * from profiles loop
   perform refresh_profile_social_counts(r.user_id);
   update profiles set scoreboard_score=calculate_fuskamo_score(r.user_id),scoreboard_updated_at=now() where user_id=r.user_id;
 end loop;
end $$;

-- Final reputation synchronization: keep profile appearance, trust and the
-- scoreboard score as three separate values. This replaces the earlier
-- trigger that accidentally copied trust into profile_completion.
create or replace function refresh_profile_reputation(p_user uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare c numeric; t numeric; s numeric;
begin
  c := calculate_profile_completion(p_user);
  t := calculate_profile_trust(p_user);
  s := calculate_fuskamo_score(p_user);
  update profiles
  set profile_completion=c, trust_score=t, scoreboard_score=s, scoreboard_updated_at=now(), updated_at=now()
  where user_id=p_user;
end;
$$;
grant execute on function refresh_profile_reputation(uuid) to authenticated;

create or replace function on_profile_like_changed_v3()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare target uuid;
begin
 target := coalesce(new.user_id,old.user_id);
 perform refresh_profile_social_counts(target);
 perform refresh_profile_reputation(target);
 return coalesce(new,old);
end;
$$;
drop trigger if exists trg_profile_like_trust on profile_likes;
drop trigger if exists trg_profile_like_scoreboard on profile_likes;
create trigger trg_profile_like_reputation after insert or delete on profile_likes for each row execute function on_profile_like_changed_v3();

create or replace function on_profile_achievement_changed_v3()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare target uuid;
begin
 target := coalesce(new.user_id,old.user_id);
 perform refresh_profile_social_counts(target);
 perform refresh_profile_reputation(target);
 return coalesce(new,old);
end;
$$;
drop trigger if exists trg_profile_achievement_reputation on profile_achievements;
create trigger trg_profile_achievement_reputation after insert or delete on profile_achievements for each row execute function on_profile_achievement_changed_v3();

-- Rebuild all cached reputation fields after migration.
do $$
declare r profiles;
begin
 for r in select * from profiles loop
   perform refresh_profile_social_counts(r.user_id);
   perform refresh_profile_reputation(r.user_id);
 end loop;
end $$;
-- FUSKAMO Social Content V1
-- Posts, comments, stories, reels, reactions, discovery/search, creator analytics,
-- content moderation and safety. Media is URL-based so this does not require FUSKAMO
-- to become a video host; storage/CDN can be attached later.

create or replace function is_platform_admin(p_permission text default 'content:moderate')
returns boolean language sql security definer set search_path=public stable as $$
  select exists (
    select 1
    from admin_users au
    join admin_role_permissions arp on arp.role_id = au.role_id
    join admin_permissions ap on ap.id = arp.permission_id
    where au.id = auth.uid() and au.status = 'active'
      and (ap.resource || ':' || ap.action) = p_permission
  );
$$;

-- ---------- POSTS ----------
create table if not exists social_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 5000),
  media_url text,
  media_type text not null default 'none' check (media_type in ('none','image','external_video')),
  visibility text not null default 'public' check (visibility in ('public','followers','private')),
  status text not null default 'published' check (status in ('draft','published','hidden','removed')),
  reply_to_id uuid references social_posts(id) on delete set null,
  repost_of_id uuid references social_posts(id) on delete set null,
  quote_of_id uuid references social_posts(id) on delete set null,
  like_count integer not null default 0 check (like_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  repost_count integer not null default 0 check (repost_count >= 0),
  view_count integer not null default 0 check (view_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(trim(body)) > 0 or media_url is not null)
);
create index if not exists idx_social_posts_author_created on social_posts(author_id, created_at desc);
create index if not exists idx_social_posts_public_created on social_posts(created_at desc) where visibility='public' and status='published';
create index if not exists idx_social_posts_reply on social_posts(reply_to_id, created_at);

create table if not exists social_post_likes (
  post_id uuid not null references social_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);
create index if not exists idx_social_post_likes_user on social_post_likes(user_id,created_at desc);

create table if not exists social_post_views (
  post_id uuid not null references social_posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  session_id text not null,
  watch_ms integer not null default 0 check (watch_ms >= 0 and watch_ms <= 86400000),
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  primary key(post_id,session_id)
);
create index if not exists idx_social_post_views_user on social_post_views(user_id,created_at desc);

create table if not exists social_reposts (
  post_id uuid not null references social_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);

-- ---------- COMMENTS ----------
create table if not exists social_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references social_posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid references social_comments(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  status text not null default 'published' check (status in ('published','hidden','removed')),
  like_count integer not null default 0 check (like_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_social_comments_post on social_comments(post_id,created_at);
create index if not exists idx_social_comments_parent on social_comments(parent_id,created_at);

create table if not exists social_comment_likes (
  comment_id uuid not null references social_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(comment_id,user_id)
);

-- ---------- STORIES ----------
create table if not exists social_stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  media_url text not null,
  media_type text not null default 'image' check (media_type in ('image','external_video')),
  caption text not null default '' check (char_length(caption) <= 1000),
  visibility text not null default 'followers' check (visibility in ('public','followers','close_friends')),
  status text not null default 'published' check (status in ('published','hidden','removed')),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now()
);
create index if not exists idx_social_stories_active on social_stories(expires_at desc,created_at desc) where status='published';
create index if not exists idx_social_stories_author on social_stories(author_id,created_at desc);

create table if not exists social_story_views (
  story_id uuid not null references social_stories(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key(story_id,viewer_id)
);
create index if not exists idx_story_views_viewer on social_story_views(viewer_id,viewed_at desc);

create table if not exists social_story_reactions (
  story_id uuid not null references social_stories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null default 'like' check (reaction in ('like','love','fire','support','wow')),
  created_at timestamptz not null default now(),
  primary key(story_id,user_id)
);

create table if not exists social_story_replies (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references social_stories(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

-- ---------- REELS ----------
create table if not exists social_reels (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  video_url text not null,
  caption text not null default '' check (char_length(caption) <= 2200),
  thumbnail_url text,
  duration_ms integer not null default 0 check (duration_ms >= 0 and duration_ms <= 3600000),
  visibility text not null default 'public' check (visibility in ('public','followers','private')),
  status text not null default 'published' check (status in ('draft','published','hidden','removed')),
  like_count integer not null default 0 check (like_count >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  share_count integer not null default 0 check (share_count >= 0),
  view_count integer not null default 0 check (view_count >= 0),
  completion_count integer not null default 0 check (completion_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_social_reels_public on social_reels(created_at desc) where visibility='public' and status='published';
create index if not exists idx_social_reels_author on social_reels(author_id,created_at desc);

create table if not exists social_reel_likes (
  reel_id uuid not null references social_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(reel_id,user_id)
);

create table if not exists social_reel_views (
  reel_id uuid not null references social_reels(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  session_id text not null,
  watch_ms integer not null default 0 check (watch_ms >= 0 and watch_ms <= 86400000),
  completed boolean not null default false,
  rewatches integer not null default 0 check (rewatches >= 0),
  created_at timestamptz not null default now(),
  primary key(reel_id,session_id)
);
create index if not exists idx_social_reel_views_user on social_reel_views(user_id,created_at desc);

create table if not exists social_reel_comments (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references social_reels(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid references social_reel_comments(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  status text not null default 'published' check(status in ('published','hidden','removed')),
  created_at timestamptz not null default now()
);
create index if not exists idx_social_reel_comments_reel on social_reel_comments(reel_id,created_at);

-- ---------- MODERATION ----------
create table if not exists content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check(target_type in ('post','comment','story','reel','profile','group','message')),
  target_id uuid not null,
  reason text not null check(reason in ('spam','harassment','impersonation','scam','hate','sexual','violence','copyright','misinformation','other')),
  details text not null default '' check(char_length(details)<=2000),
  status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
  reviewer_id uuid references auth.users(id),
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists idx_content_reports_queue on content_reports(status,created_at desc);
create index if not exists idx_content_reports_target on content_reports(target_type,target_id,created_at desc);

create table if not exists moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid references auth.users(id) on delete cascade,
  target_type text not null check(target_type in ('user','post','comment','story','reel','group')),
  target_id uuid not null,
  action text not null check(action in ('warn','hide','restore','remove','suspend','unsuspend','restrict','ban')),
  reason text not null,
  duration_until timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_moderation_actions_target on moderation_actions(target_type,target_id,created_at desc);

create table if not exists user_restrictions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active' check(status in ('active','restricted','suspended','banned')),
  reason text not null default '',
  until_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ---------- CREATOR ANALYTICS ----------
create table if not exists creator_daily_metrics (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  post_impressions bigint not null default 0,
  post_likes bigint not null default 0,
  post_comments bigint not null default 0,
  post_reposts bigint not null default 0,
  reel_views bigint not null default 0,
  reel_completions bigint not null default 0,
  story_views bigint not null default 0,
  followers_gained bigint not null default 0,
  profile_visits bigint not null default 0,
  reports_received bigint not null default 0,
  primary key(user_id,day)
);

-- ---------- SECURITY ----------
alter table social_posts enable row level security;
alter table social_post_likes enable row level security;
alter table social_post_views enable row level security;
alter table social_reposts enable row level security;
alter table social_comments enable row level security;
alter table social_comment_likes enable row level security;
alter table social_stories enable row level security;
alter table social_story_views enable row level security;
alter table social_story_reactions enable row level security;
alter table social_story_replies enable row level security;
alter table social_reels enable row level security;
alter table social_reel_likes enable row level security;
alter table social_reel_views enable row level security;
alter table social_reel_comments enable row level security;
alter table content_reports enable row level security;
alter table moderation_actions enable row level security;
alter table user_restrictions enable row level security;
alter table creator_daily_metrics enable row level security;

create policy "Published public posts readable" on social_posts for select using (
  status='published' and (visibility='public' or author_id=auth.uid() or (visibility='followers' and exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=author_id)))
);
create policy "Users create their posts" on social_posts for insert with check(author_id=auth.uid() and not exists(select 1 from user_restrictions r where r.user_id=auth.uid() and r.status in ('suspended','banned')));
create policy "Authors edit posts" on social_posts for update using(author_id=auth.uid()) with check(author_id=auth.uid());
create policy "Authors delete posts" on social_posts for delete using(author_id=auth.uid());

create policy "Public post likes readable" on social_post_likes for select using(true);
create policy "Users like posts" on social_post_likes for insert with check(user_id=auth.uid());
create policy "Users unlike posts" on social_post_likes for delete using(user_id=auth.uid());
create policy "Users create post views" on social_post_views for insert with check(user_id=auth.uid() or user_id is null);
create policy "Users read own post views" on social_post_views for select using(user_id=auth.uid());
create policy "Users repost" on social_reposts for insert with check(user_id=auth.uid());
create policy "Users undo repost" on social_reposts for delete using(user_id=auth.uid());

create policy "Visible comments readable" on social_comments for select using(status='published');
create policy "Users create comments" on social_comments for insert with check(author_id=auth.uid());
create policy "Authors edit comments" on social_comments for update using(author_id=auth.uid()) with check(author_id=auth.uid());
create policy "Authors delete comments" on social_comments for delete using(author_id=auth.uid());
create policy "Comment likes readable" on social_comment_likes for select using(true);
create policy "Users like comments" on social_comment_likes for insert with check(user_id=auth.uid());
create policy "Users unlike comments" on social_comment_likes for delete using(user_id=auth.uid());

create policy "Active stories readable" on social_stories for select using(
  status='published' and expires_at > now() and (visibility='public' or author_id=auth.uid() or (visibility='followers' and exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=author_id)))
);
create policy "Users create stories" on social_stories for insert with check(author_id=auth.uid());
create policy "Authors manage stories" on social_stories for update using(author_id=auth.uid()) with check(author_id=auth.uid());
create policy "Authors delete stories" on social_stories for delete using(author_id=auth.uid());
create policy "Users view stories" on social_story_views for insert with check(viewer_id=auth.uid());
create policy "Users read own story views" on social_story_views for select using(viewer_id=auth.uid());
create policy "Users react to stories" on social_story_reactions for insert with check(user_id=auth.uid());
create policy "Users remove story reactions" on social_story_reactions for delete using(user_id=auth.uid());
create policy "Users reply to stories" on social_story_replies for insert with check(sender_id=auth.uid());
create policy "Senders read their story replies" on social_story_replies for select using(sender_id=auth.uid());

create policy "Visible reels readable" on social_reels for select using(
  status='published' and (visibility='public' or author_id=auth.uid() or (visibility='followers' and exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=author_id)))
);
create policy "Users create reels" on social_reels for insert with check(author_id=auth.uid());
create policy "Authors manage reels" on social_reels for update using(author_id=auth.uid()) with check(author_id=auth.uid());
create policy "Authors delete reels" on social_reels for delete using(author_id=auth.uid());
create policy "Reel likes readable" on social_reel_likes for select using(true);
create policy "Users like reels" on social_reel_likes for insert with check(user_id=auth.uid());
create policy "Users unlike reels" on social_reel_likes for delete using(user_id=auth.uid());
create policy "Users create reel views" on social_reel_views for insert with check(user_id=auth.uid() or user_id is null);
create policy "Users read own reel views" on social_reel_views for select using(user_id=auth.uid());
create policy "Visible reel comments readable" on social_reel_comments for select using(status='published');
create policy "Users create reel comments" on social_reel_comments for insert with check(author_id=auth.uid());
create policy "Authors edit reel comments" on social_reel_comments for update using(author_id=auth.uid()) with check(author_id=auth.uid());
create policy "Authors delete reel comments" on social_reel_comments for delete using(author_id=auth.uid());

create policy "Users submit reports" on content_reports for insert with check(reporter_id=auth.uid());
create policy "Users see their reports" on content_reports for select using(reporter_id=auth.uid() or is_platform_admin('reports:view'));
create policy "Admins manage reports" on content_reports for update using(is_platform_admin('reports:resolve')) with check(is_platform_admin('reports:resolve'));
create policy "Admins see moderation actions" on moderation_actions for select using(is_platform_admin('content:view'));
create policy "Admins create moderation actions" on moderation_actions for insert with check(moderator_id=auth.uid() and is_platform_admin('content:moderate'));
create policy "Users see own restrictions" on user_restrictions for select using(user_id=auth.uid());
create policy "Admins manage restrictions" on user_restrictions for all using(is_platform_admin('users:manage')) with check(is_platform_admin('users:manage'));
create policy "Creators see their analytics" on creator_daily_metrics for select using(user_id=auth.uid() or is_platform_admin('analytics:view'));

-- ---------- COUNTERS / MODERATION RPCS ----------
create or replace function toggle_post_like(p_post uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare liked boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if exists(select 1 from user_restrictions where user_id=auth.uid() and status in ('suspended','banned')) then raise exception 'Account cannot engage'; end if;
  if exists(select 1 from social_post_likes where post_id=p_post and user_id=auth.uid()) then
    delete from social_post_likes where post_id=p_post and user_id=auth.uid(); liked:=false;
  else
    insert into social_post_likes(post_id,user_id) values(p_post,auth.uid()); liked:=true;
  end if;
  update social_posts set like_count=(select count(*) from social_post_likes where post_id=p_post) where id=p_post;
  return liked;
end; $$;
grant execute on function toggle_post_like(uuid) to authenticated;

create or replace function toggle_reel_like(p_reel uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare liked boolean;
begin
  if exists(select 1 from social_reel_likes where reel_id=p_reel and user_id=auth.uid()) then
    delete from social_reel_likes where reel_id=p_reel and user_id=auth.uid(); liked:=false;
  else
    insert into social_reel_likes(reel_id,user_id) values(p_reel,auth.uid()); liked:=true;
  end if;
  update social_reels set like_count=(select count(*) from social_reel_likes where reel_id=p_reel) where id=p_reel;
  return liked;
end; $$;
grant execute on function toggle_reel_like(uuid) to authenticated;

create or replace function record_reel_view(p_reel uuid,p_session text,p_watch_ms integer,p_completed boolean,p_rewatch integer default 0)
returns void language plpgsql security definer set search_path=public as $$
declare was_completed boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select completed into was_completed from social_reel_views where reel_id=p_reel and session_id=p_session;
  insert into social_reel_views(reel_id,user_id,session_id,watch_ms,completed,rewatches)
  values(p_reel,auth.uid(),p_session,greatest(0,p_watch_ms),p_completed,greatest(0,p_rewatch))
  on conflict(reel_id,session_id) do update set watch_ms=greatest(social_reel_views.watch_ms,excluded.watch_ms), completed=social_reel_views.completed or excluded.completed, rewatches=greatest(social_reel_views.rewatches,excluded.rewatches);
  update social_reels set view_count=(select count(*) from social_reel_views where reel_id=p_reel), completion_count=(select count(*) from social_reel_views where reel_id=p_reel and completed) where id=p_reel;
end; $$;
grant execute on function record_reel_view(uuid,text,integer,boolean,integer) to authenticated;

create or replace function record_post_view(p_post uuid,p_session text,p_watch_ms integer default 0)
returns void language plpgsql security definer set search_path=public as $$
begin
  insert into social_post_views(post_id,user_id,session_id,watch_ms) values(p_post,auth.uid(),p_session,greatest(0,p_watch_ms)) on conflict(post_id,session_id) do update set watch_ms=greatest(social_post_views.watch_ms,excluded.watch_ms);
  update social_posts set view_count=(select count(*) from social_post_views where post_id=p_post) where id=p_post;
end; $$;
grant execute on function record_post_view(uuid,text,integer) to authenticated;

create or replace function search_fuskamo(p_query text,p_limit integer default 30)
returns table(kind text,id uuid,title text,subtitle text,username text,avatar_url text,verified boolean,badge_type text)
language plpgsql security definer set search_path=public as $$
declare q text:=trim(p_query); lim integer:=least(greatest(p_limit,1),50);
begin
  if q='' then return; end if;
  return query
  select 'profile',p.user_id,p.display_name,p.role,p.username,p.avatar_url,p.verified,p.badge_type from profiles p
  where p.display_name ilike '%'||q||'%' or p.username ilike lower('%'||q||'%') order by p.verified desc,p.followers_count desc limit lim;
end; $$;
grant execute on function search_fuskamo(text,integer) to authenticated;

create or replace function get_creator_analytics(p_days integer default 30)
returns table(day date,post_impressions bigint,post_likes bigint,post_comments bigint,post_reposts bigint,reel_views bigint,reel_completions bigint,story_views bigint,followers_gained bigint,reports_received bigint)
language sql security definer set search_path=public as $$
 select day,post_impressions,post_likes,post_comments,post_reposts,reel_views,reel_completions,story_views,followers_gained,reports_received
 from creator_daily_metrics where user_id=auth.uid() and day >= current_date - least(greatest(p_days,1),365) order by day;
$$;
grant execute on function get_creator_analytics(integer) to authenticated;

create or replace function moderate_content(p_target_type text,p_target_id uuid,p_action text,p_reason text,p_duration timestamptz default null)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not is_platform_admin('content:moderate') then raise exception 'Moderator permission required'; end if;
 insert into moderation_actions(moderator_id,target_type,target_id,action,reason,duration_until) values(auth.uid(),p_target_type,p_target_id,p_action,p_reason,p_duration);
 if p_target_type='post' then update social_posts set status=case when p_action='restore' then 'published' when p_action in ('hide','remove') then case when p_action='hide' then 'hidden' else 'removed' end else status end where id=p_target_id;
 elsif p_target_type='comment' then update social_comments set status=case when p_action='restore' then 'published' when p_action in ('hide','remove') then case when p_action='hide' then 'hidden' else 'removed' end else status end where id=p_target_id;
 elsif p_target_type='reel' then update social_reels set status=case when p_action='restore' then 'published' when p_action in ('hide','remove') then case when p_action='hide' then 'hidden' else 'removed' end else status end where id=p_target_id;
 elsif p_target_type='story' then update social_stories set status=case when p_action='restore' then 'published' when p_action in ('hide','remove') then case when p_action='hide' then 'hidden' else 'removed' end else status end where id=p_target_id;
 end if;
end; $$;
grant execute on function moderate_content(text,uuid,text,text,timestamptz) to authenticated;

-- Realtime for social feeds. Add tables only if not already present in publication.
do $$ begin
  alter publication supabase_realtime add table social_posts;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table social_comments;
exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table social_reels;
exception when duplicate_object then null; when undefined_object then null; end $$;

-- Expired stories are retained for analytics but disappear from active queries through RLS.
create or replace function purge_old_social_metrics()
returns void language sql security definer set search_path=public as $$
  delete from social_story_views where viewed_at < now() - interval '90 days';
$$;

-- Recompute post comment/repost counters after client writes.
create or replace function refresh_social_post_counts(p_post uuid)
returns void language sql security definer set search_path=public as $$
  update social_posts p set
    comment_count=(select count(*) from social_comments c where c.post_id=p.id and c.status='published'),
    repost_count=(select count(*) from social_reposts r where r.post_id=p.id)
  where p.id=p_post;
$$;
grant execute on function refresh_social_post_counts(uuid) to authenticated;

-- Expand universal search to the actual FUSKAMO entities. The function only
-- returns public/approved records and never exposes secret group metadata.
drop function if exists search_fuskamo(text,integer);
create or replace function search_fuskamo(p_query text,p_limit integer default 30)
returns table(kind text,id uuid,title text,subtitle text,username text,avatar_url text,verified boolean,badge_type text)
language plpgsql security definer set search_path=public as $$
declare q text:=trim(p_query); lim integer:=least(greatest(p_limit,1),50);
begin
 if q='' then return; end if;
 return query
 select * from (
   select 'profile'::text kind,p.user_id id,p.display_name title,p.role subtitle,p.username,p.avatar_url,p.verified,p.badge_type
   from profiles p where p.display_name ilike '%'||q||'%' or p.username ilike lower('%'||q||'%')
   union all
   select 'group',g.id,g.name,g.category,g.slug,g.avatar_url,g.verified,'gold'
   from groups g where g.privacy <> 'secret' and (g.name ilike '%'||q||'%' or g.slug ilike lower('%'||q||'%') or g.description ilike '%'||q||'%')
   union all
   select 'player',p.id,p.name,p.position,p.name,null,false,'none'
   from players p where p.status='approved' and p.name ilike '%'||q||'%'
   union all
   select 'scout',s.id,s.name,coalesce(s.organization,'Scout'),null,null,s.verified,case when s.verified then 'blue' else 'none' end
   from scouts s where s.verified=true and s.name ilike '%'||q||'%'
   union all
   select 'post',sp.id,left(sp.body,80),'post',null,null,false,'none'
   from social_posts sp where sp.status='published' and sp.visibility='public' and sp.body ilike '%'||q||'%'
   union all
   select 'reel',sr.id,left(sr.caption,80),'reel',null,sr.thumbnail_url,false,'none'
   from social_reels sr where sr.status='published' and sr.visibility='public' and sr.caption ilike '%'||q||'%'
 ) x order by verified desc,title asc limit lim;
end; $$;
grant execute on function search_fuskamo(text,integer) to authenticated;

-- ---------- SOCIAL RANKING ----------
-- This is a transparent first-stage social ranker, not fake ML. It uses
-- freshness, relationship, meaningful engagement and safety. Later a trained
-- ranker can replace this function without changing the client contract.
create or replace function get_social_feed(p_limit integer default 30)
returns setof social_posts
language sql security definer set search_path=public as $$
  select sp.*
  from social_posts sp
  where sp.status='published' and sp.visibility='public'
  order by (
    ln(1+sp.like_count)*1.20 +
    ln(1+sp.comment_count)*2.00 +
    ln(1+sp.repost_count)*1.50 +
    ln(1+sp.view_count)*0.20 +
    case when exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=sp.author_id) then 3.0 else 0 end +
    greatest(0, 4 - extract(epoch from (now()-sp.created_at))/21600.0)
  ) desc, sp.created_at desc
  limit least(greatest(p_limit,1),50);
$$;
grant execute on function get_social_feed(integer) to authenticated;

create or replace function get_social_reels(p_limit integer default 30)
returns setof social_reels
language sql security definer set search_path=public as $$
  select sr.* from social_reels sr
  where sr.status='published' and sr.visibility='public'
  order by (
    ln(1+sr.like_count)*1.0 +
    ln(1+sr.comment_count)*1.8 +
    ln(1+sr.share_count)*1.5 +
    case when sr.view_count > 0 then (sr.completion_count::numeric/sr.view_count)*4 else 0 end +
    greatest(0, 4 - extract(epoch from (now()-sr.created_at))/21600.0)
  ) desc, sr.created_at desc
  limit least(greatest(p_limit,1),50);
$$;
grant execute on function get_social_reels(integer) to authenticated;

create or replace function refresh_creator_daily_metrics(p_user uuid,p_day date default current_date)
returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() <> p_user and not is_platform_admin('analytics:view') then raise exception 'Not allowed'; end if;
  insert into creator_daily_metrics(user_id,day,post_impressions,post_likes,post_comments,post_reposts,reel_views,reel_completions,story_views,followers_gained,reports_received)
  select p_user,p_day,
    coalesce((select count(*) from social_post_views v join social_posts p on p.id=v.post_id where p.author_id=p_user and v.created_at::date=p_day),0),
    coalesce((select count(*) from social_post_likes l join social_posts p on p.id=l.post_id where p.author_id=p_user and l.created_at::date=p_day),0),
    coalesce((select count(*) from social_comments c join social_posts p on p.id=c.post_id where p.author_id=p_user and c.created_at::date=p_day and c.status='published'),0),
    coalesce((select count(*) from social_reposts r join social_posts p on p.id=r.post_id where p.author_id=p_user and r.created_at::date=p_day),0),
    coalesce((select count(*) from social_reel_views v join social_reels r on r.id=v.reel_id where r.author_id=p_user and v.created_at::date=p_day),0),
    coalesce((select count(*) from social_reel_views v join social_reels r on r.id=v.reel_id where r.author_id=p_user and v.completed and v.created_at::date=p_day),0),
    coalesce((select count(*) from social_story_views v join social_stories s on s.id=v.story_id where s.author_id=p_user and v.viewed_at::date=p_day),0),
    coalesce((select count(*) from profile_follows f where f.followed_id=p_user and f.created_at::date=p_day),0),
    coalesce((select count(*) from content_reports cr where cr.target_id in (select id from social_posts where author_id=p_user) and cr.created_at::date=p_day),0)
  on conflict(user_id,day) do update set
    post_impressions=excluded.post_impressions,post_likes=excluded.post_likes,post_comments=excluded.post_comments,
    post_reposts=excluded.post_reposts,reel_views=excluded.reel_views,reel_completions=excluded.reel_completions,
    story_views=excluded.story_views,followers_gained=excluded.followers_gained,reports_received=excluded.reports_received;
end; $$;
grant execute on function refresh_creator_daily_metrics(uuid,date) to authenticated;

create or replace function get_creator_analytics(p_days integer default 30)
returns table(day date,post_impressions bigint,post_likes bigint,post_comments bigint,post_reposts bigint,reel_views bigint,reel_completions bigint,story_views bigint,followers_gained bigint,reports_received bigint)
language plpgsql security definer set search_path=public as $$
declare d date;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  for d in select generate_series(current_date-least(greatest(p_days,1),365)+1,current_date,interval '1 day')::date loop
    perform refresh_creator_daily_metrics(auth.uid(),d);
  end loop;
  return query select c.day,c.post_impressions,c.post_likes,c.post_comments,c.post_reposts,c.reel_views,c.reel_completions,c.story_views,c.followers_gained,c.reports_received from creator_daily_metrics c where c.user_id=auth.uid() and c.day>=current_date-least(greatest(p_days,1),365)+1 order by c.day;
end; $$;
grant execute on function get_creator_analytics(integer) to authenticated;

create or replace function get_moderation_queue(p_limit integer default 50)
returns setof content_reports
language sql security definer set search_path=public as $$
  select * from content_reports where is_platform_admin('reports:view') and status in ('open','reviewing') order by created_at asc limit least(greatest(p_limit,1),100);
$$;
grant execute on function get_moderation_queue(integer) to authenticated;

create or replace function resolve_content_report(p_report uuid,p_status text,p_resolution text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not is_platform_admin('reports:resolve') then raise exception 'Report resolution permission required'; end if;
 if p_status not in ('resolved','dismissed') then raise exception 'Invalid resolution status'; end if;
 update content_reports set status=p_status,resolution=p_resolution,reviewer_id=auth.uid(),resolved_at=now() where id=p_report;
end; $$;
grant execute on function resolve_content_report(uuid,text,text) to authenticated;

create or replace function record_story_view(p_story uuid)
returns void language sql security definer set search_path=public as $$
  insert into social_story_views(story_id,viewer_id) values(p_story,auth.uid()) on conflict(story_id,viewer_id) do update set viewed_at=now();
$$;
grant execute on function record_story_view(uuid) to authenticated;

create or replace function moderate_content(p_target_type text,p_target_id uuid,p_action text,p_reason text,p_duration timestamptz default null)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not is_platform_admin('content:moderate') then raise exception 'Moderator permission required'; end if;
 insert into moderation_actions(moderator_id,target_type,target_id,action,reason,duration_until) values(auth.uid(),p_target_type,p_target_id,p_action,p_reason,p_duration);
 if p_target_type='post' then update social_posts set status=case when p_action='restore' then 'published' when p_action='hide' then 'hidden' when p_action='remove' then 'removed' else status end where id=p_target_id;
 elsif p_target_type='comment' then update social_comments set status=case when p_action='restore' then 'published' when p_action='hide' then 'hidden' when p_action='remove' then 'removed' else status end where id=p_target_id;
 elsif p_target_type='reel' then update social_reels set status=case when p_action='restore' then 'published' when p_action='hide' then 'hidden' when p_action='remove' then 'removed' else status end where id=p_target_id;
 elsif p_target_type='story' then update social_stories set status=case when p_action='restore' then 'published' when p_action='hide' then 'hidden' when p_action='remove' then 'removed' else status end where id=p_target_id;
 elsif p_target_type='profile' then
   if p_action in ('suspend','ban','restrict','unsuspend') then
     insert into user_restrictions(user_id,status,reason,until_at) values(p_target_id,case when p_action='ban' then 'banned' when p_action='suspend' then 'suspended' when p_action='restrict' then 'restricted' else 'active' end,p_reason,p_duration)
     on conflict(user_id) do update set status=excluded.status,reason=excluded.reason,until_at=excluded.until_at,updated_at=now();
   end if;
 end if;
end; $$;
grant execute on function moderate_content(text,uuid,text,text,timestamptz) to authenticated;
alter table moderation_actions drop constraint if exists moderation_actions_target_type_check;
alter table moderation_actions add constraint moderation_actions_target_type_check check(target_type in ('user','profile','post','comment','story','reel','group'));

create or replace function refresh_social_reel_counts(p_reel uuid)
returns void language sql security definer set search_path=public as $$
  update social_reels r set
    comment_count=(select count(*) from social_reel_comments c where c.reel_id=r.id and c.status='published'),
    like_count=(select count(*) from social_reel_likes l where l.reel_id=r.id)
  where r.id=p_reel;
$$;
grant execute on function refresh_social_reel_counts(uuid) to authenticated;
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
-- FUSKAMO Unified Graph V1
-- Identity -> Social Graph -> Content -> Recommendation -> Scoreboard -> Trust/Safety.
-- Deliberate anti-feedback-loop rule: recommendation exposure NEVER increases trust or verification.
-- Exposure can contribute to momentum only after a meaningful downstream action.

create table if not exists graph_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  subject_user_id uuid references auth.users(id) on delete set null,
  object_type text not null check (object_type in ('profile','post','reel','story','group','message','player','scout','club')),
  object_id uuid not null,
  event_type text not null check (event_type in ('impression','open','view','watch','complete','like','comment','reply','save','share','repost','follow','join','message','contact','skip','not_interested','mute','block','report')),
  value numeric(12,4) not null default 1,
  session_id text,
  ip_hash text,
  device_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_graph_events_object_time on graph_events(object_type,object_id,created_at desc);
create index if not exists idx_graph_events_actor_time on graph_events(actor_id,created_at desc);
create index if not exists idx_graph_events_subject_time on graph_events(subject_user_id,created_at desc);
create index if not exists idx_graph_events_type_time on graph_events(event_type,created_at desc);

create table if not exists safety_risk_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  risk_score numeric(6,4) not null default 0 check(risk_score between 0 and 1),
  trust_penalty numeric(6,4) not null default 0 check(trust_penalty between 0 and 1),
  strike_count integer not null default 0 check(strike_count >= 0),
  enforcement_state text not null default 'normal' check(enforcement_state in ('normal','watch','restricted','suspended','banned')),
  last_reason text,
  last_reviewed_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists idx_safety_state on safety_risk_profiles(enforcement_state,risk_score desc);

create table if not exists recommendation_impressions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  object_type text not null check(object_type in ('profile','post','reel','group','player','scout','club')),
  object_id uuid not null,
  position integer not null check(position > 0),
  score numeric(12,4) not null,
  model_version text not null default 'unified-v1',
  shown_at timestamptz not null default now(),
  acted_at timestamptz,
  action_type text
);
create index if not exists idx_rec_impressions_user on recommendation_impressions(user_id,shown_at desc);
create index if not exists idx_rec_impressions_object on recommendation_impressions(object_type,object_id,shown_at desc);

create table if not exists scoreboard_snapshots (
  user_id uuid not null references auth.users(id) on delete cascade,
  snapshot_date date not null,
  score numeric(8,4) not null check(score between 0 and 100),
  momentum numeric(8,4) not null check(momentum between 0 and 100),
  trust numeric(8,4) not null check(trust between 0 and 100),
  meaningful_engagement numeric(8,4) not null check(meaningful_engagement between 0 and 100),
  safety numeric(8,4) not null check(safety between 0 and 100),
  primary key(user_id,snapshot_date)
);

alter table graph_events enable row level security;
alter table safety_risk_profiles enable row level security;
alter table recommendation_impressions enable row level security;
alter table scoreboard_snapshots enable row level security;

create policy "Users can read own graph events" on graph_events for select using(actor_id=auth.uid());
create policy "Users can create own graph events" on graph_events for insert with check(actor_id=auth.uid());
create policy "Users can read own safety profile" on safety_risk_profiles for select using(user_id=auth.uid());
create policy "Users can read own recommendation impressions" on recommendation_impressions for select using(user_id=auth.uid());
create policy "Users can create own recommendation impressions" on recommendation_impressions for insert with check(user_id=auth.uid());
create policy "Users can read own scoreboard snapshots" on scoreboard_snapshots for select using(user_id=auth.uid());

-- A bounded, server-side event recorder. It deliberately rejects reputation events
-- that would be too easy to self-farm and never lets the client set IP/device hashes.
create or replace function record_graph_event(
  p_object_type text,
  p_object_id uuid,
  p_event_type text,
  p_subject_user_id uuid default null,
  p_value numeric default 1,
  p_session_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_confirmed timestamptz;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_event_type in ('like','comment','reply','save','share','repost','follow','join','message','contact') then
    select email_confirmed_at into v_confirmed from auth.users where id=auth.uid();
    if v_confirmed is null then raise exception 'Confirm your email before creating reputation events'; end if;
  end if;
  if p_object_type not in ('profile','post','reel','story','group','message','player','scout','club') then raise exception 'Invalid graph object'; end if;
  if p_event_type not in ('impression','open','view','watch','complete','like','comment','reply','save','share','repost','follow','join','message','contact','skip','not_interested','mute','block','report') then raise exception 'Invalid graph event'; end if;

  -- Prevent obvious repeated impression farming: one impression per object/session/10 minutes.
  if p_event_type='impression' and p_session_id is not null and exists(
    select 1 from graph_events where actor_id=auth.uid() and object_type=p_object_type and object_id=p_object_id
      and event_type='impression' and session_id=p_session_id and created_at > now()-interval '10 minutes'
  ) then return null; end if;

  insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type,value,session_id,metadata)
  values(auth.uid(),p_subject_user_id,p_object_type,p_object_id,p_event_type,greatest(-100,least(100,coalesce(p_value,1))),p_session_id,coalesce(p_metadata,'{}'::jsonb))
  returning id into v_id;
  return v_id;
end; $$;
grant execute on function record_graph_event(text,uuid,text,uuid,numeric,text,jsonb) to authenticated;

-- Safety score is evidence-based and capped. Reports alone do not ban anybody.
create or replace function recompute_user_safety(p_user uuid)
returns numeric language plpgsql security definer set search_path=public as $$
declare reports numeric:=0; blocks numeric:=0; spam numeric:=0; positive numeric:=0; risk numeric:=0;
begin
  select count(*) into reports from content_reports where reporter_id <> p_user and target_id in (select id from social_posts where author_id=p_user);
  select count(*) into blocks from user_blocks where blocked_id=p_user;
  select count(*) into spam from graph_events where subject_user_id=p_user and event_type in ('report','not_interested','block') and created_at>now()-interval '30 days';
  select count(*) into positive from graph_events where subject_user_id=p_user and event_type in ('save','share','contact','follow','join') and created_at>now()-interval '30 days';
  risk := least(1,greatest(0,(reports*0.08)+(blocks*0.03)+(spam*0.04)-(positive*0.002)));
  insert into safety_risk_profiles(user_id,risk_score,trust_penalty,updated_at) values(p_user,risk,risk,now())
  on conflict(user_id) do update set risk_score=excluded.risk_score,trust_penalty=excluded.trust_penalty,updated_at=now();
  return risk;
end; $$;
revoke all on function recompute_user_safety(uuid) from public;
grant execute on function recompute_user_safety(uuid) to authenticated;

-- Scoreboard V2: meaningful outcomes beat raw popularity. Verification is a trust
-- input only; recommendation exposure itself is never a score source.
create or replace function calculate_fuskamo_score(p_user uuid)
returns numeric language plpgsql security definer set search_path=public as $$
declare p profiles; trust numeric:=0; followers numeric:=0; likes numeric:=0; achievements numeric:=0; momentum numeric:=0; meaningful numeric:=0; safety numeric:=100; quality numeric:=0; score numeric:=0; role_quality numeric:=0; risk numeric:=0;
begin
 select * into p from profiles where user_id=p_user; if not found then return 0; end if;
 trust:=coalesce(p.trust_score,0); followers:=coalesce(p.followers_count,0); likes:=coalesce(p.profile_likes_count,0); achievements:=least(100,coalesce(p.achievement_points,0));
 select coalesce(risk_score,0) into risk from safety_risk_profiles where user_id=p_user;
 safety:=100-(coalesce(risk,0)*100);
 select coalesce(sum(case when event_type in ('save','share','repost','contact','join','complete') then 1 else 0 end),0) into meaningful from graph_events where subject_user_id=p_user and created_at>now()-interval '30 days';
 select coalesce(sum(case when event_type in ('follow','like','comment','reply','save','share','repost','contact','complete') then 1 else 0 end),0) into momentum from graph_events where subject_user_id=p_user and created_at>now()-interval '7 days';
 if p.role='player' then select coalesce(max(quality_score),0)*100 into role_quality from players where submitted_by=p_user and status='approved';
 elsif p.role='scout' then role_quality:=case when p.verified then 100 else 55 end;
 elsif p.role='club' then role_quality:=case when p.verified then 100 else 55 end;
 elsif p.role='coach' then role_quality:=case when p.verified then 100 else 55 end;
 else role_quality:=coalesce(p.profile_completion,trust); end if;
 quality:=least(100,role_quality);
 score:=quality*0.25 + trust*0.20 + least(100,ln(likes+1)/ln(251.0)*100)*0.10 + least(100,ln(followers+1)/ln(1001.0)*100)*0.10 + achievements*0.10 + least(100,meaningful/50.0*100)*0.10 + least(100,momentum/20.0*100)*0.05 + safety*0.10;
 score:=score*(0.75+0.25*(safety/100));
 update profiles set scoreboard_score=round(score::numeric,2),momentum_score=round(least(100,momentum/20.0*100)::numeric,2),scoreboard_updated_at=now() where user_id=p_user;
 insert into scoreboard_snapshots(user_id,snapshot_date,score,momentum,trust,meaningful_engagement,safety) values(p_user,current_date,score,least(100,momentum/20.0*100),trust,least(100,meaningful/50.0*100),safety)
 on conflict(user_id,snapshot_date) do update set score=excluded.score,momentum=excluded.momentum,trust=excluded.trust,meaningful_engagement=excluded.meaningful_engagement,safety=excluded.safety;
 return round(score::numeric,2);
end; $$;
grant execute on function calculate_fuskamo_score(uuid) to authenticated;

-- Public-safe scoreboard remains the existing get_fuskamo_scoreboard contract.
-- This refresh helper lets a signed-in user update their own score after meaningful activity.
create or replace function refresh_my_scoreboard_score_v2()
returns numeric language sql security definer set search_path=public as $$
  select calculate_fuskamo_score(auth.uid());
$$;
grant execute on function refresh_my_scoreboard_score_v2() to authenticated;

-- Recommendation candidates: public content and public identities only. Secret groups
-- and private/follower-only content are never candidate-generated here.
create or replace function get_unified_candidate_signals(p_limit integer default 200)
returns table(object_type text,object_id uuid,author_id uuid,role text,quality numeric,trust numeric,safety numeric,created_at timestamptz,engagement numeric)
language sql security definer set search_path=public as $$
  with blocked as (
    select blocked_id as user_id from user_blocks where blocker_id=auth.uid()
    union select blocker_id from user_blocks where blocked_id=auth.uid()
  ),
  people as (
    select 'profile'::text object_type,p.user_id object_id,p.user_id author_id,p.role,
      coalesce(p.profile_completion,0)::numeric quality,coalesce(p.trust_score,0)::numeric trust,
      100-coalesce(sr.risk_score,0)*100 safety,p.created_at,
      (ln(1+p.followers_count)+ln(1+p.profile_likes_count))::numeric engagement
    from profiles p left join safety_risk_profiles sr on sr.user_id=p.user_id
    where p.role<>'admin' and p.user_id<>auth.uid() and not exists(select 1 from blocked b where b.user_id=p.user_id)
  ),
  posts as (
    select 'post'::text,sp.id,sp.author_id,coalesce(p.role,'fan'),
      least(100,(sp.like_count+sp.comment_count*2+sp.repost_count*2+sp.view_count*0.05)),
      coalesce(p.trust_score,0),100-coalesce(sr.risk_score,0)*100,sp.created_at,
      (ln(1+sp.like_count)+ln(1+sp.comment_count)*2+ln(1+sp.repost_count)*2+ln(1+sp.view_count)*0.2)::numeric
    from social_posts sp join profiles p on p.user_id=sp.author_id left join safety_risk_profiles sr on sr.user_id=sp.author_id
    where sp.status='published' and sp.visibility='public' and not exists(select 1 from blocked b where b.user_id=sp.author_id)
  ),
  reels as (
    select 'reel'::text,sr.id,sr.author_id,coalesce(p.role,'fan'),
      least(100,(sr.like_count+sr.comment_count*2+sr.share_count*2+sr.view_count*0.05+case when sr.view_count>0 then sr.completion_count::numeric/sr.view_count*50 else 0 end)),
      coalesce(p.trust_score,0),100-coalesce(sp.risk_score,0)*100,sr.created_at,
      (ln(1+sr.like_count)+ln(1+sr.comment_count)*2+ln(1+sr.share_count)*2+ln(1+sr.view_count)*0.2+case when sr.view_count>0 then sr.completion_count::numeric/sr.view_count*4 else 0 end)::numeric
    from social_reels sr join profiles p on p.user_id=sr.author_id left join safety_risk_profiles sp on sp.user_id=sr.author_id
    where sr.status='published' and sr.visibility='public' and not exists(select 1 from blocked b where b.user_id=sr.author_id)
  ),
  groups_public as (
    select 'group'::text,g.id,g.owner_id,coalesce(p.role,'fan'),least(100,g.member_count*0.1+g.host_count*2),coalesce(p.trust_score,0),100-coalesce(sr.risk_score,0)*100,g.created_at,ln(1+g.member_count)+ln(1+g.host_count)*2
    from groups g join profiles p on p.user_id=g.owner_id left join safety_risk_profiles sr on sr.user_id=g.owner_id
    where g.privacy='public' and not exists(select 1 from blocked b where b.user_id=g.owner_id)
  )
  select * from (select * from people union all select * from posts union all select * from reels union all select * from groups_public) c
  order by created_at desc limit least(greatest(p_limit,1),500);
$$;
grant execute on function get_unified_candidate_signals(integer) to authenticated;

-- ---------- AUTOMATIC GRAPH EVENT BRIDGES ----------
-- Existing feature tables remain the source of truth. These bridges feed the
-- unified graph without asking every Flutter screen to remember telemetry.
create or replace function bridge_profile_follow_graph_event()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type) values(auth.uid(),new.followed_id,'profile',new.followed_id,'follow')
  on conflict do nothing;
  return new;
end; $$;
drop trigger if exists trg_graph_follow on profile_follows;
create trigger trg_graph_follow after insert on profile_follows for each row execute function bridge_profile_follow_graph_event();

create or replace function bridge_post_like_graph_event()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_posts where id=new.post_id; insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type) values(auth.uid(),owner_id,'post',new.post_id,'like'); return new; end; $$;
drop trigger if exists trg_graph_post_like on social_post_likes;
create trigger trg_graph_post_like after insert on social_post_likes for each row execute function bridge_post_like_graph_event();

create or replace function bridge_post_comment_graph_event()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_posts where id=new.post_id; insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type) values(auth.uid(),owner_id,'post',new.post_id,case when new.parent_id is null then 'comment' else 'reply' end); return new; end; $$;
drop trigger if exists trg_graph_post_comment on social_comments;
create trigger trg_graph_post_comment after insert on social_comments for each row execute function bridge_post_comment_graph_event();

create or replace function bridge_post_repost_graph_event()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_posts where id=new.post_id; insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type) values(auth.uid(),owner_id,'post',new.post_id,'repost'); return new; end; $$;
drop trigger if exists trg_graph_post_repost on social_reposts;
create trigger trg_graph_post_repost after insert on social_reposts for each row execute function bridge_post_repost_graph_event();

create or replace function bridge_reel_like_graph_event()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_reels where id=new.reel_id; insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type) values(auth.uid(),owner_id,'reel',new.reel_id,'like'); return new; end; $$;
drop trigger if exists trg_graph_reel_like on social_reel_likes;
create trigger trg_graph_reel_like after insert on social_reel_likes for each row execute function bridge_reel_like_graph_event();

create or replace function bridge_reel_comment_graph_event()
returns trigger language plpgsql security definer set search_path=public as $$
declare owner_id uuid; begin select author_id into owner_id from social_reels where id=new.reel_id; insert into graph_events(actor_id,subject_user_id,object_type,object_id,event_type) values(auth.uid(),owner_id,'reel',new.reel_id,'comment'); return new; end; $$;
drop trigger if exists trg_graph_reel_comment on social_reel_comments;
create trigger trg_graph_reel_comment after insert on social_reel_comments for each row execute function bridge_reel_comment_graph_event();

-- ---------- SAFETY-AWARE SOCIAL FEEDS ----------
create or replace function get_social_feed(p_limit integer default 30)
returns setof social_posts
language sql security definer set search_path=public as $$
  select sp.* from social_posts sp
  join profiles author on author.user_id=sp.author_id
  left join safety_risk_profiles sr on sr.user_id=sp.author_id
  where sp.status='published' and sp.visibility='public'
    and sp.author_id<>auth.uid()
    and coalesce(sr.risk_score,0) < 0.75
    and not exists(select 1 from user_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=sp.author_id) or (b.blocker_id=sp.author_id and b.blocked_id=auth.uid()))
  order by (
    case when exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=sp.author_id) then 18 else 0 end +
    least(100,coalesce(author.trust_score,0))*0.18 +
    greatest(0,100-coalesce(sr.risk_score,0)*100)*0.10 +
    ln(1+sp.like_count)*1.2 + ln(1+sp.comment_count)*2 + ln(1+sp.repost_count)*1.5 +
    greatest(0,4-extract(epoch from (now()-sp.created_at))/21600.0)
  ) desc, sp.created_at desc
  limit least(greatest(p_limit,1),50);
$$;
grant execute on function get_social_feed(integer) to authenticated;

create or replace function get_social_reels(p_limit integer default 30)
returns setof social_reels
language sql security definer set search_path=public as $$
  select sr.* from social_reels sr
  join profiles author on author.user_id=sr.author_id
  left join safety_risk_profiles risk on risk.user_id=sr.author_id
  where sr.status='published' and sr.visibility='public'
    and sr.author_id<>auth.uid()
    and coalesce(risk.risk_score,0)<0.75
    and not exists(select 1 from user_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=sr.author_id) or (b.blocker_id=sr.author_id and b.blocked_id=auth.uid()))
  order by (
    case when exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=sr.author_id) then 18 else 0 end +
    least(100,coalesce(author.trust_score,0))*0.15 +
    greatest(0,100-coalesce(risk.risk_score,0)*100)*0.10 +
    ln(1+sr.like_count)*1.0 + ln(1+sr.comment_count)*1.8 + ln(1+sr.share_count)*1.5 +
    case when sr.view_count>0 then (sr.completion_count::numeric/sr.view_count)*8 else 0 end +
    greatest(0,4-extract(epoch from (now()-sr.created_at))/21600.0)
  ) desc, sr.created_at desc
  limit least(greatest(p_limit,1),50);
$$;
grant execute on function get_social_reels(integer) to authenticated;
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
-- FUSKAMO Social Platform V2 — free-build completion for systems 1–10.
-- No paid provider is required. Video remains URL/CDN-ready but hosting can stay disabled.
-- Verification is NEVER granted by profile appearance, likes, follows, payment, or scoreboard.

begin;

-- ============================================================
-- 1. MESSAGING V2
-- ============================================================
create table if not exists message_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(sender_id,recipient_id),
  check(sender_id <> recipient_id)
);
create index if not exists idx_message_requests_recipient on message_requests(recipient_id,status,created_at desc);
create index if not exists idx_message_requests_sender on message_requests(sender_id,status,created_at desc);

create table if not exists direct_message_reactions (
  message_id uuid not null references direct_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check(reaction in ('like','love','laugh','wow','sad','fire')),
  created_at timestamptz not null default now(),
  primary key(message_id,user_id)
);
create index if not exists idx_dm_reactions_message on direct_message_reactions(message_id);

create table if not exists direct_message_receipts (
  message_id uuid not null references direct_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  delivered_at timestamptz,
  read_at timestamptz,
  primary key(message_id,user_id)
);

create table if not exists direct_message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references direct_messages(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check(kind in ('image','file','audio','video')),
  url text not null,
  mime_type text,
  byte_size bigint check(byte_size is null or byte_size >= 0),
  created_at timestamptz not null default now()
);

create table if not exists typing_presence (
  conversation_id uuid not null references direct_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  primary key(conversation_id,user_id)
);

alter table message_requests enable row level security;
alter table direct_message_reactions enable row level security;
alter table direct_message_receipts enable row level security;
alter table direct_message_attachments enable row level security;
alter table typing_presence enable row level security;

create policy "Users see own message requests" on message_requests for select using(auth.uid()=sender_id or auth.uid()=recipient_id);
create policy "Users create message requests" on message_requests for insert with check(auth.uid()=sender_id and sender_id<>recipient_id);
create policy "Recipients or senders update message requests" on message_requests for update using(auth.uid()=sender_id or auth.uid()=recipient_id) with check(auth.uid()=sender_id or auth.uid()=recipient_id);
create policy "Users manage own message reactions" on direct_message_reactions for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "Participants see message receipts" on direct_message_receipts for select using(exists(select 1 from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id where m.id=message_id and p.user_id=auth.uid()));
create policy "Users create own receipts" on direct_message_receipts for insert with check(auth.uid()=user_id);
create policy "Users update own receipts" on direct_message_receipts for update using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "Participants see message attachments" on direct_message_attachments for select using(exists(select 1 from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id where m.id=message_id and p.user_id=auth.uid()));
create policy "Users create own message attachments" on direct_message_attachments for insert with check(auth.uid()=owner_id);
create policy "Users delete own message attachments" on direct_message_attachments for delete using(auth.uid()=owner_id);
create policy "Participants see typing presence" on typing_presence for select using(exists(select 1 from direct_conversation_participants p where p.conversation_id=typing_presence.conversation_id and p.user_id=auth.uid()));
create policy "Users manage own typing presence" on typing_presence for all using(auth.uid()=user_id) with check(auth.uid()=user_id);

create or replace function can_message_user(p_sender uuid,p_recipient uuid)
returns boolean language plpgsql security definer set search_path=public stable as $$
declare pref text; follower boolean; blocked boolean;
begin
 if p_sender is null or p_recipient is null or p_sender=p_recipient then return false; end if;
 select exists(select 1 from user_blocks where blocker_id=p_sender and blocked_id=p_recipient or blocker_id=p_recipient and blocked_id=p_sender) into blocked;
 if blocked then return false; end if;
 select coalesce(message_requests,'everyone') into pref from profiles where user_id=p_recipient;
 if pref='nobody' then return false; end if;
 if pref='followers' then
   select exists(select 1 from profile_follows where follower_id=p_sender and followed_id=p_recipient) into follower;
   return follower;
 end if;
 return true;
end; $$;
grant execute on function can_message_user(uuid,uuid) to authenticated;

create or replace function request_or_open_conversation(p_other_user uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare mine uuid:=auth.uid(); cid uuid; req message_requests;
begin
 if mine is null then raise exception 'Authentication required'; end if;
 if not can_message_user(mine,p_other_user) then raise exception 'Messaging is not available for this account'; end if;
 select p.conversation_id into cid from direct_conversation_participants p join direct_conversation_participants q on q.conversation_id=p.conversation_id where p.user_id=mine and q.user_id=p_other_user limit 1;
 if cid is not null then return cid; end if;
 select * into req from message_requests where sender_id=mine and recipient_id=p_other_user and status='pending';
 if req.id is null then
   insert into message_requests(sender_id,recipient_id,status) values(mine,p_other_user,'accepted') on conflict(sender_id,recipient_id) do update set status='accepted',updated_at=now();
 end if;
 return get_or_create_direct_conversation(p_other_user);
end; $$;
grant execute on function request_or_open_conversation(uuid) to authenticated;

create or replace function send_message_request(p_recipient uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare mine uuid:=auth.uid(); rid uuid;
begin
 if mine is null or p_recipient is null or mine=p_recipient then raise exception 'Invalid recipient'; end if;
 if exists(select 1 from user_blocks where (blocker_id=mine and blocked_id=p_recipient) or (blocker_id=p_recipient and blocked_id=mine)) then raise exception 'Messaging is blocked'; end if;
 insert into message_requests(sender_id,recipient_id,status) values(mine,p_recipient,'pending') on conflict(sender_id,recipient_id) do update set status='pending',updated_at=now() returning id into rid;
 return rid;
end; $$;
grant execute on function send_message_request(uuid) to authenticated;

create or replace function respond_message_request(p_request uuid,p_accept boolean)
returns uuid language plpgsql security definer set search_path=public as $$
declare r message_requests; cid uuid;
begin
 select * into r from message_requests where id=p_request and recipient_id=auth.uid() for update;
 if not found then raise exception 'Request not found'; end if;
 if p_accept then
   update message_requests set status='accepted',updated_at=now() where id=p_request;
   cid:=get_or_create_direct_conversation(r.sender_id);
   return cid;
 else
   update message_requests set status='declined',updated_at=now() where id=p_request;
   return null;
 end if;
end; $$;
grant execute on function respond_message_request(uuid,boolean) to authenticated;

create or replace function toggle_direct_message_reaction(p_message uuid,p_reaction text)
returns boolean language plpgsql security definer set search_path=public as $$
declare exists_now boolean;
begin
 if not exists(select 1 from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id where m.id=p_message and p.user_id=auth.uid()) then raise exception 'Not a participant'; end if;
 select exists(select 1 from direct_message_reactions where message_id=p_message and user_id=auth.uid()) into exists_now;
 if exists_now then delete from direct_message_reactions where message_id=p_message and user_id=auth.uid(); return false; end if;
 insert into direct_message_reactions(message_id,user_id,reaction) values(p_message,auth.uid(),p_reaction); return true;
end; $$;
grant execute on function toggle_direct_message_reaction(uuid,text) to authenticated;

create or replace function mark_direct_message_delivered(p_message uuid)
returns void language sql security definer set search_path=public as $$
insert into direct_message_receipts(message_id,user_id,delivered_at)
select m.id,auth.uid(),now() from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id
where m.id=p_message and p.user_id=auth.uid() on conflict(message_id,user_id) do update set delivered_at=coalesce(direct_message_receipts.delivered_at,now());
$$;
grant execute on function mark_direct_message_delivered(uuid) to authenticated;

create or replace function mark_direct_message_read(p_message uuid)
returns void language sql security definer set search_path=public as $$
insert into direct_message_receipts(message_id,user_id,delivered_at,read_at)
select m.id,auth.uid(),now(),now() from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id
where m.id=p_message and p.user_id=auth.uid() on conflict(message_id,user_id) do update set delivered_at=coalesce(direct_message_receipts.delivered_at,now()),read_at=now();
$$;
grant execute on function mark_direct_message_read(uuid) to authenticated;

-- Tighten direct-message insertion: blocks/restrictions/message-request rules are checked server-side.
drop policy if exists "Participants can send messages" on direct_messages;
create policy "Participants can send messages v2" on direct_messages for insert with check(
 sender_id=auth.uid() and exists(select 1 from direct_conversation_participants me where me.conversation_id=direct_messages.conversation_id and me.user_id=auth.uid())
 and not exists(select 1 from user_restrictions r where r.user_id=auth.uid() and r.status in ('suspended','banned'))
 and not exists(select 1 from direct_conversation_participants other where other.conversation_id=direct_messages.conversation_id and other.user_id<>auth.uid() and not can_message_user(auth.uid(),other.user_id))
);

-- ============================================================
-- 2. STORIES V2
-- ============================================================
create table if not exists close_friends (
  owner_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(owner_id,friend_id),
  check(owner_id<>friend_id)
);
create table if not exists story_highlights (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check(char_length(trim(title)) between 1 and 40),
  cover_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists story_highlight_items (
  highlight_id uuid not null references story_highlights(id) on delete cascade,
  story_id uuid not null references social_stories(id) on delete cascade,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  primary key(highlight_id,story_id)
);
alter table close_friends enable row level security; alter table story_highlights enable row level security; alter table story_highlight_items enable row level security;
create policy "Users manage close friends" on close_friends for all using(auth.uid()=owner_id) with check(auth.uid()=owner_id);
create policy "Public highlights readable" on story_highlights for select using(true);
create policy "Owners manage highlights" on story_highlights for all using(auth.uid()=owner_id) with check(auth.uid()=owner_id);
create policy "Highlight items readable" on story_highlight_items for select using(exists(select 1 from story_highlights h where h.id=highlight_id));
create policy "Owners manage highlight items" on story_highlight_items for all using(exists(select 1 from story_highlights h where h.id=highlight_id and h.owner_id=auth.uid())) with check(exists(select 1 from story_highlights h where h.id=highlight_id and h.owner_id=auth.uid()));

drop policy if exists "Active stories readable" on social_stories;
create policy "Active stories readable v2" on social_stories for select using(
 status='published' and expires_at>now() and (
  visibility='public' or author_id=auth.uid() or
  (visibility='followers' and exists(select 1 from profile_follows f where f.follower_id=auth.uid() and f.followed_id=author_id)) or
  (visibility='close_friends' and exists(select 1 from close_friends cf where cf.owner_id=author_id and cf.friend_id=auth.uid()))
 )
);

-- ============================================================
-- 3. REELS V2
-- ============================================================
create table if not exists social_reel_saves (
  reel_id uuid not null references social_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(reel_id,user_id)
);
create table if not exists social_reel_shares (
  id uuid primary key default gen_random_uuid(), reel_id uuid not null references social_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade, channel text not null default 'share', created_at timestamptz not null default now()
);
create table if not exists social_reel_feedback (
  reel_id uuid not null references social_reels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  feedback text not null check(feedback in ('not_interested','hide_creator','show_more')), created_at timestamptz not null default now(), primary key(reel_id,user_id)
);
alter table social_reel_saves enable row level security; alter table social_reel_shares enable row level security; alter table social_reel_feedback enable row level security;
create policy "Users manage reel saves" on social_reel_saves for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "Users create reel shares" on social_reel_shares for insert with check(auth.uid()=user_id);
create policy "Users read own reel shares" on social_reel_shares for select using(auth.uid()=user_id);
create policy "Users manage reel feedback" on social_reel_feedback for all using(auth.uid()=user_id) with check(auth.uid()=user_id);

create or replace function toggle_reel_save(p_reel uuid) returns boolean language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from social_reel_saves where reel_id=p_reel and user_id=auth.uid()) then delete from social_reel_saves where reel_id=p_reel and user_id=auth.uid(); return false; end if;
 insert into social_reel_saves(reel_id,user_id) values(p_reel,auth.uid()); return true;
end; $$;
grant execute on function toggle_reel_save(uuid) to authenticated;
create or replace function record_reel_share(p_reel uuid,p_channel text default 'share') returns void language sql security definer set search_path=public as $$
insert into social_reel_shares(reel_id,user_id,channel) values(p_reel,auth.uid(),left(coalesce(p_channel,'share'),30)); update social_reels set share_count=(select count(*) from social_reel_shares where reel_id=p_reel) where id=p_reel;
$$;
grant execute on function record_reel_share(uuid,text) to authenticated;

-- ============================================================
-- 4. POSTS V2
-- ============================================================
create table if not exists social_post_saves (
  post_id uuid not null references social_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(post_id,user_id)
);
create table if not exists social_post_media (
  id uuid primary key default gen_random_uuid(), post_id uuid not null references social_posts(id) on delete cascade,
  media_url text not null, media_type text not null check(media_type in ('image','external_video','document','audio')),
  position integer not null default 0, alt_text text, created_at timestamptz not null default now()
);
create table if not exists social_hashtags (
  id uuid primary key default gen_random_uuid(), tag text unique not null check(tag=lower(tag)), created_at timestamptz not null default now()
);
create table if not exists social_post_hashtags (
  post_id uuid not null references social_posts(id) on delete cascade,
  hashtag_id uuid not null references social_hashtags(id) on delete cascade, primary key(post_id,hashtag_id)
);
create table if not exists social_post_mentions (
  post_id uuid not null references social_posts(id) on delete cascade,
  mentioned_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(), primary key(post_id,mentioned_user_id)
);
alter table social_post_saves enable row level security; alter table social_post_media enable row level security; alter table social_hashtags enable row level security; alter table social_post_hashtags enable row level security; alter table social_post_mentions enable row level security;
create policy "Users manage post saves" on social_post_saves for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "Visible post media readable" on social_post_media for select using(exists(select 1 from social_posts p where p.id=post_id and p.status='published'));
create policy "Authors manage post media" on social_post_media for all using(exists(select 1 from social_posts p where p.id=post_id and p.author_id=auth.uid())) with check(exists(select 1 from social_posts p where p.id=post_id and p.author_id=auth.uid()));
create policy "Hashtags public" on social_hashtags for select using(true);
create policy "Post hashtags public" on social_post_hashtags for select using(true);
create policy "Authors manage post hashtags" on social_post_hashtags for insert with check(exists(select 1 from social_posts p where p.id=post_id and p.author_id=auth.uid()));
create policy "Post mentions public" on social_post_mentions for select using(true);
create policy "Authors create post mentions" on social_post_mentions for insert with check(exists(select 1 from social_posts p where p.id=post_id and p.author_id=auth.uid()));

create or replace function toggle_post_save(p_post uuid) returns boolean language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from social_post_saves where post_id=p_post and user_id=auth.uid()) then delete from social_post_saves where post_id=p_post and user_id=auth.uid(); return false; end if;
 insert into social_post_saves(post_id,user_id) values(p_post,auth.uid()); return true;
end; $$;
grant execute on function toggle_post_save(uuid) to authenticated;

create or replace function create_repost(p_post uuid,p_quote text default null) returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid;
begin
 if exists(select 1 from social_reposts where post_id=p_post and user_id=auth.uid()) then return null; end if;
 insert into social_posts(author_id,body,visibility,status,repost_of_id,quote_of_id) values(auth.uid(),coalesce(p_quote,''),'public','published',p_post,case when nullif(trim(p_quote),'') is not null then p_post else null end) returning id into new_id;
 insert into social_reposts(post_id,user_id) values(p_post,auth.uid());
 update social_posts set repost_count=(select count(*) from social_reposts where post_id=p_post) where id=p_post;
 return new_id;
end; $$;
grant execute on function create_repost(uuid,text) to authenticated;

create or replace function notify_social_mention() returns trigger language plpgsql security definer set search_path=public as $$
declare author uuid; uname text;
begin
 select author_id into author from social_posts where id=new.post_id;
 select username into uname from profiles where user_id=author;
 if to_regprocedure('enqueue_notification_event(uuid,uuid,text,text,text,text,uuid,text,text,jsonb)') is not null then
   perform enqueue_notification_event(new.mentioned_user_id,author,'mention','You were mentioned',coalesce('@'||uname,'Someone')||' mentioned you in a post','post',new.post_id,'/post/'||new.post_id::text,'mention:'||new.post_id::text||':'||new.mentioned_user_id::text,'{}'::jsonb);
 end if;
 return new;
end; $$;
drop trigger if exists trg_social_post_mention_notification on social_post_mentions;
create trigger trg_social_post_mention_notification after insert on social_post_mentions for each row execute function notify_social_mention();

-- ============================================================
-- 5. GROUPS V2
-- ============================================================
create table if not exists group_bans (
  group_id uuid not null references groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  banned_by uuid not null references auth.users(id),
  reason text not null default '', expires_at timestamptz, created_at timestamptz not null default now(), primary key(group_id,user_id)
);
create table if not exists group_role_permissions (
  group_id uuid not null references groups(id) on delete cascade,
  role text not null check(role in ('owner','host','moderator','member')),
  permission text not null check(permission in ('send_messages','pin','delete_messages','create_polls','manage_members','manage_invites','manage_rules','view_host_chat')),
  enabled boolean not null default true, primary key(group_id,role,permission)
);
create table if not exists group_daily_metrics (
  group_id uuid not null references groups(id) on delete cascade,
  day date not null, active_members integer not null default 0, messages integer not null default 0, new_members integer not null default 0,
  poll_votes integer not null default 0, reports integer not null default 0, primary key(group_id,day)
);
alter table group_bans enable row level security; alter table group_role_permissions enable row level security; alter table group_daily_metrics enable row level security;
create policy "Group members see bans" on group_bans for select using(is_group_member(group_id));
create policy "Staff manage bans" on group_bans for all using(is_group_staff(group_id)) with check(is_group_staff(group_id) and banned_by=auth.uid());
create policy "Members read group role permissions" on group_role_permissions for select using(is_group_member(group_id));
create policy "Owners manage group role permissions" on group_role_permissions for all using(is_group_owner(group_id)) with check(is_group_owner(group_id));
create policy "Staff read group metrics" on group_daily_metrics for select using(is_group_staff(group_id));

create or replace function can_group_permission(p_group uuid,p_permission text,p_user uuid default auth.uid()) returns boolean language sql security definer set search_path=public as $$
select exists(select 1 from group_members gm left join group_role_permissions rp on rp.group_id=gm.group_id and rp.role=gm.role and rp.permission=p_permission where gm.group_id=p_group and gm.user_id=p_user and coalesce(rp.enabled,case when gm.role='owner' then true else p_permission in ('send_messages','view_host_chat') and gm.role in ('host','moderator') end));
$$;
grant execute on function can_group_permission(uuid,text,uuid) to authenticated;

-- Ensure existing hosts/moderators can pin at any time; this replaces implicit time-based assumptions.
drop policy if exists "group_pins_staff" on group_pins;
create policy "group_pins_staff v2" on group_pins for all using(can_group_permission(group_id,'pin')) with check(can_group_permission(group_id,'pin'));

-- ============================================================
-- 6. VERIFICATION V2
-- ============================================================
-- Critical correction: approved player/scout records are NOT automatic verification ticks.
alter table profiles drop constraint if exists profiles_username_check;
alter table profiles add constraint profiles_username_canonical_check check(username is null or username ~ '^[a-z][a-z0-9_]{2,19}$');
create unique index if not exists ux_profiles_username_lower on profiles(lower(username)) where username is not null;

create table if not exists username_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  username text not null,
  changed_at timestamptz not null default now(), primary key(user_id,username)
);
alter table username_history enable row level security;
create policy "Username history public" on username_history for select using(true);
create policy "Users cannot write username history" on username_history for insert with check(false);

create or replace function ensure_my_profile(
  p_display_name text default null,p_username text default null,p_bio text default null,p_avatar_url text default null,p_website text default null,
  p_instagram text default null,p_x_handle text default null,p_tiktok text default null,p_snapchat text default null,p_bluesky text default null,p_role text default 'player')
returns profiles language plpgsql security definer set search_path=public as $$
declare r profiles; normalized text; old_username text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_role not in ('player','scout','coach','club','fan') then p_role:='fan'; end if;
 normalized:=nullif(lower(trim(p_username)),'');
 if normalized is not null and normalized !~ '^[a-z][a-z0-9_]{2,19}$' then raise exception 'Username must be 3–20 characters: lowercase letters, numbers and underscores only, starting with a letter'; end if;
 select username into old_username from profiles where user_id=auth.uid();
 if old_username is not null and normalized is not null and old_username<>normalized and exists(select 1 from username_history where user_id=auth.uid() and changed_at>now()-interval '30 days') then raise exception 'Username can only be changed every 30 days'; end if;
 insert into profiles(user_id,display_name,username,bio,avatar_url,website,instagram,x_handle,tiktok,snapchat,bluesky,role,verified,badge_type)
 values(auth.uid(),coalesce(nullif(trim(p_display_name),''),'FUSKAMO Member'),normalized,coalesce(p_bio,''),p_avatar_url,p_website,p_instagram,p_x_handle,p_tiktok,p_snapchat,p_bluesky,p_role,false,'none')
 on conflict(user_id) do update set display_name=coalesce(nullif(trim(p_display_name),''),profiles.display_name),username=coalesce(normalized,profiles.username),bio=coalesce(p_bio,profiles.bio),avatar_url=coalesce(p_avatar_url,profiles.avatar_url),website=coalesce(p_website,profiles.website),instagram=coalesce(p_instagram,profiles.instagram),x_handle=coalesce(p_x_handle,profiles.x_handle),tiktok=coalesce(p_tiktok,profiles.tiktok),snapchat=coalesce(p_snapchat,profiles.snapchat),bluesky=coalesce(p_bluesky,profiles.bluesky),role=case when profiles.verified then profiles.role else p_role end,updated_at=now()
 returning * into r;
 if old_username is distinct from r.username and r.username is not null then insert into username_history(user_id,username) values(auth.uid(),r.username) on conflict do nothing; end if;
 return r;
end; $$;
grant execute on function ensure_my_profile(text,text,text,text,text,text,text,text,text,text,text) to authenticated;

-- ============================================================
-- 7. ACHIEVEMENTS V2
-- ============================================================
create table if not exists achievement_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid not null references badge_achievements(id) on delete cascade,
  progress numeric not null default 0 check(progress>=0), target numeric not null default 100 check(target>0), updated_at timestamptz not null default now(), primary key(user_id,achievement_id)
);
create table if not exists achievement_events (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id uuid references badge_achievements(id) on delete set null, event_type text not null, points numeric not null default 0, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table achievement_progress enable row level security; alter table achievement_events enable row level security;
create policy "Public achievement progress" on achievement_progress for select using(true);
create policy "Users read achievement events" on achievement_events for select using(auth.uid()=user_id);

insert into badge_achievements(code,name,description,icon,points) values
('first_post','First Post','Published your first FUSKAMO post.','✦',5),
('first_group','Community Builder','Created your first FUSKAMO group.','◎',10),
('helpful_voice','Helpful Voice','Built positive comment participation without repeated moderation violations.','◈',20),
('rising_creator','Rising Creator','Built sustained authentic content engagement.','↗',30),
('season_leader','Season Leader','Finished a FUSKAMO scoreboard season among the leading accounts in your role.','♛',50)
on conflict(code) do nothing;

create or replace function award_completed_achievements(p_user uuid default auth.uid()) returns integer language plpgsql security definer set search_path=public as $$
declare n integer:=0; a record; prog record;
begin
 for a in select ap.achievement_id,ap.progress,ap.target from achievement_progress ap where ap.user_id=p_user loop
   if a.progress>=a.target then
     insert into profile_achievements(user_id,achievement_id,awarded_reason,source) values(p_user,a.achievement_id,'Achievement target completed','system') on conflict do nothing;
     if found then n:=n+1; insert into achievement_events(user_id,achievement_id,event_type,points) select p_user,a.achievement_id,'awarded',ba.points from badge_achievements ba where ba.id=a.achievement_id; end if;
   end if;
 end loop;
 return n;
end; $$;
grant execute on function award_completed_achievements(uuid) to authenticated;

create or replace function refresh_my_achievement_progress() returns void language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); ach record; likes_n integer; posts_n integer; groups_n integer; comments_n integer; violations integer;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 select count(*) into likes_n from profile_likes where user_id=uid;
 select count(*) into posts_n from social_posts where author_id=uid and status='published';
 select count(*) into groups_n from groups where owner_id=uid;
 select count(*) into comments_n from social_comments where author_id=uid and status='published';
 select count(*) into violations from moderation_cases where target_user_id=uid and status in ('actioned','resolved');
 for ach in select id,code from badge_achievements where active loop
   if ach.code='community_rising' then insert into achievement_progress values(uid,ach.id,least(likes_n,25),25,now()) on conflict(user_id,achievement_id) do update set progress=excluded.progress,updated_at=now();
   elsif ach.code='well_known' then insert into achievement_progress values(uid,ach.id,least(likes_n,250),250,now()) on conflict(user_id,achievement_id) do update set progress=excluded.progress,updated_at=now();
   elsif ach.code='first_post' then insert into achievement_progress values(uid,ach.id,least(posts_n,1),1,now()) on conflict(user_id,achievement_id) do update set progress=excluded.progress,updated_at=now();
   elsif ach.code='first_group' then insert into achievement_progress values(uid,ach.id,least(groups_n,1),1,now()) on conflict(user_id,achievement_id) do update set progress=excluded.progress,updated_at=now();
   elsif ach.code='helpful_voice' then insert into achievement_progress values(uid,ach.id,least(greatest(comments_n-violations*5,0),100),100,now()) on conflict(user_id,achievement_id) do update set progress=excluded.progress,updated_at=now();
   end if;
 end loop;
 perform award_completed_achievements(uid);
end; $$;
grant execute on function refresh_my_achievement_progress() to authenticated;



-- ============================================================
-- 8. SCOREBOARD V2
-- ============================================================
create table if not exists scoreboard_seasons (
  id uuid primary key default gen_random_uuid(), name text unique not null, starts_at timestamptz not null, ends_at timestamptz not null, active boolean not null default false, check(ends_at>starts_at)
);
create table if not exists scoreboard_rankings (
  season_id uuid not null references scoreboard_seasons(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null, rank integer not null, score numeric not null, snapshot_at timestamptz not null default now(), primary key(season_id,user_id,category)
);
alter table scoreboard_seasons enable row level security; alter table scoreboard_rankings enable row level security;
create policy "Active scoreboard seasons public" on scoreboard_seasons for select using(active=true);
create policy "Public scoreboard rankings" on scoreboard_rankings for select using(true);

create or replace function calculate_scoreboard_score_v2(p_user uuid) returns numeric language plpgsql security definer set search_path=public as $$
declare p profiles; quality numeric:=0; trust numeric:=0; followers numeric:=0; likes numeric:=0; achievements numeric:=0; momentum numeric:=0; safety numeric:=1; reports integer:=0;
begin
 select * into p from profiles where user_id=p_user; if not found then return 0; end if;
 trust:=coalesce(p.trust_score,0); followers:=least(100,ln(coalesce(p.followers_count,0)+1)/ln(1001.0)*100); likes:=least(100,ln(coalesce(p.profile_likes_count,0)+1)/ln(1001.0)*100); achievements:=least(100,coalesce(p.achievement_points,0)); momentum:=least(100,coalesce(p.momentum_score,0));
 if p.role='player' then select coalesce(max(quality_score)*100,0) into quality from players where submitted_by=p_user and status='approved'; else quality:=case when p.verified then 100 else coalesce(p.profile_completion,50) end; end if;
 select count(*) into reports from moderation_cases where target_user_id=p_user and status in ('actioned','resolved') and created_at>now()-interval '90 days';
 safety:=greatest(0.45,1-least(0.55,reports*0.05));
 return round(greatest(0,least(100,(quality*.30+trust*.20+likes*.15+followers*.10+achievements*.10+momentum*.10+coalesce(p.profile_completion,0)*.05)*safety)),2);
end; $$;
grant execute on function calculate_scoreboard_score_v2(uuid) to authenticated;

-- ============================================================
-- 9. UNIVERSAL SEARCH V2
-- ============================================================
create or replace function search_fuskamo_v2(p_query text,p_limit integer default 40)
returns table(kind text,id uuid,title text,subtitle text,username text,avatar_url text,verified boolean,badge_type text,score numeric)
language sql security definer set search_path=public as $$
with q as (select lower(trim(coalesce(p_query,''))) term), rows as (
 select 'profile' kind,p.user_id id,p.display_name title,upper(p.role) subtitle,p.username,p.avatar_url,p.verified,p.badge_type,
  (case when lower(coalesce(p.username,''))=q.term then 100 when lower(coalesce(p.username,'')) like q.term||'%' then 80 when lower(coalesce(p.display_name,'')) like '%'||q.term||'%' then 60 else 30 end)::numeric score
 from profiles p,q where q.term<>'' and (lower(coalesce(p.username,'')) like '%'||q.term||'%' or lower(coalesce(p.display_name,'')) like '%'||q.term||'%')
 union all
 select 'group',g.id,g.name,g.category,null,g.avatar_url,false,'none',(case when lower(g.name)=q.term then 90 when lower(g.name) like q.term||'%' then 70 else 40 end)::numeric from groups g,q where q.term<>'' and g.privacy<>'secret' and (lower(g.name) like '%'||q.term||'%' or lower(g.description) like '%'||q.term||'%')
 union all
 select 'post',s.id,left(s.body,80),'POST',p.username,p.avatar_url,p.verified,p.badge_type,30::numeric from social_posts s join profiles p on p.user_id=s.author_id,q where q.term<>'' and s.status='published' and s.visibility='public' and lower(s.body) like '%'||q.term||'%'
 union all
 select 'reel',r.id,left(r.caption,80),'REEL',p.username,p.avatar_url,p.verified,p.badge_type,30::numeric from social_reels r join profiles p on p.user_id=r.author_id,q where q.term<>'' and r.status='published' and r.visibility='public' and lower(r.caption) like '%'||q.term||'%'
 union all
 select 'player',p.id,p.name,'PLAYER',null,null,false,'none',35::numeric from players p,q where q.term<>'' and p.status='approved' and lower(p.name) like '%'||q.term||'%'
 union all
 select 'scout',s.id,s.name,'SCOUT',null,null,s.verified,case when s.verified then 'blue' else 'none' end,40::numeric from scouts s,q where q.term<>'' and lower(s.name) like '%'||q.term||'%'
) select * from rows order by verified desc,score desc,title asc limit least(greatest(p_limit,1),100);
$$;
grant execute on function search_fuskamo_v2(text,integer) to authenticated;

-- Align the moderation case reason vocabulary with the policy-rule codes.
alter table moderation_cases drop constraint if exists moderation_cases_reason_check;
alter table moderation_cases add constraint moderation_cases_reason_v2_check check(reason in ('spam','spam_flood','harassment','hate','scam','impersonation','sexual','sexual_content','violence','copyright','fraud','misinformation','other'));

-- ============================================================
-- 10. MODERATION V2
-- ============================================================
create table if not exists moderation_policy_rules (
  id uuid primary key default gen_random_uuid(), code text unique not null, category text not null, severity integer not null check(severity between 1 and 5), enabled boolean not null default true, action text not null check(action in ('review','hide','restrict','suspend','ban')), description text not null
);
create table if not exists moderation_case_events (
  id uuid primary key default gen_random_uuid(), case_id uuid not null references moderation_cases(id) on delete cascade, actor_id uuid not null references auth.users(id), event_type text not null, note text, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table moderation_policy_rules enable row level security; alter table moderation_case_events enable row level security;
create policy "Moderation rules public" on moderation_policy_rules for select using(enabled=true);
create policy "Admins manage moderation rules" on moderation_policy_rules for all using(is_platform_admin('content:moderate')) with check(is_platform_admin('content:moderate'));
create policy "Moderators see case events" on moderation_case_events for select using(is_platform_admin('content:view'));
create policy "Moderators create case events" on moderation_case_events for insert with check(actor_id=auth.uid() and is_platform_admin('content:moderate'));

insert into moderation_policy_rules(code,category,severity,action,description) values
('spam_flood','spam',2,'review','Repeated or high-volume low-value activity'),
('impersonation','impersonation',5,'suspend','False affiliation with a person, club or organization'),
('scam','scam',5,'suspend','Fraudulent solicitation or payment scam'),
('harassment','harassment',3,'review','Targeted abusive behavior'),
('hate','hate',5,'suspend','Hateful or protected-class abuse'),
('sexual','sexual',5,'hide','Prohibited sexual content'),
('violence','violence',4,'hide','Graphic or threatening violent content'),
('copyright','copyright',3,'review','Copyright dispute or unauthorized content')
on conflict(code) do nothing;

create or replace function create_moderation_case(p_target_type text,p_target_id uuid,p_reason text,p_description text default '')
returns uuid language plpgsql security definer set search_path=public as $$
declare cid uuid; sev integer:=2; uid uuid:=auth.uid(); target_user uuid;
begin
 if uid is null then raise exception 'Authentication required'; end if;
 if p_target_type not in ('user','profile','post','comment','story','reel','group','message') then raise exception 'Invalid target type'; end if;
 select case
  when p_target_type in ('profile','user') then p_target_id
  when p_target_type='post' then (select author_id from social_posts where id=p_target_id)
  when p_target_type='comment' then (select author_id from social_comments where id=p_target_id)
  when p_target_type='reel' then (select author_id from social_reels where id=p_target_id)
  when p_target_type='story' then (select author_id from social_stories where id=p_target_id)
  when p_target_type='group' then (select owner_id from groups where id=p_target_id)
  when p_target_type='message' then (select sender_id from direct_messages where id=p_target_id)
  else null end into target_user;
 select coalesce(severity,2) into sev from moderation_policy_rules where code=p_reason and enabled limit 1;
 insert into moderation_cases(reporter_id,target_type,target_id,target_user_id,reason,description,severity,status) values(uid,p_target_type,p_target_id,target_user,p_reason,p_description,sev,'open') returning id into cid;
 insert into moderation_case_events(case_id,actor_id,event_type,note) values(cid,uid,'created',p_description);
 return cid;
end; $$;
grant execute on function create_moderation_case(text,uuid,text,text) to authenticated;

create or replace function resolve_moderation_case(p_case uuid,p_status text,p_resolution text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not is_platform_admin('content:moderate') then raise exception 'Moderator permission required'; end if;
 if p_status not in ('actioned','resolved','dismissed','appealed') then raise exception 'Invalid status'; end if;
 update moderation_cases set status=p_status,resolution=p_resolution,reviewer_id=auth.uid(),resolved_at=case when p_status in ('resolved','dismissed','actioned') then now() else null end,updated_at=now() where id=p_case;
 insert into moderation_case_events(case_id,actor_id,event_type,note) values(p_case,auth.uid(),p_status,p_resolution);
end; $$;
grant execute on function resolve_moderation_case(uuid,text,text) to authenticated;

commit;
-- FUSKAMO completion hardening: free-build features that close remaining
-- platform gaps without requiring a paid provider.
begin;

-- ============================================================
-- 1. STORIES: HIGHLIGHTS / CLOSE-FRIENDS MEMBERSHIP
-- ============================================================
create table if not exists story_highlights (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check(length(trim(title)) between 1 and 40),
  cover_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists story_highlight_items (
  highlight_id uuid not null references story_highlights(id) on delete cascade,
  story_id uuid not null references stories(id) on delete cascade,
  position integer not null default 0 check(position >= 0),
  added_at timestamptz not null default now(),
  primary key(highlight_id, story_id)
);
create table if not exists close_friends (
  owner_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(owner_id, friend_id),
  check(owner_id <> friend_id)
);
create index if not exists idx_story_highlights_owner on story_highlights(owner_id,updated_at desc);
create index if not exists idx_close_friends_owner on close_friends(owner_id,created_at desc);

-- ============================================================
-- 2. SEARCH: RECENT SEARCHES / SUGGESTIONS
-- ============================================================
create table if not exists search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  query text not null check(length(trim(query)) between 1 and 100),
  object_type text,
  object_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists idx_search_history_user on search_history(user_id,created_at desc);

-- ============================================================
-- 3. MODERATION: AUTOMATED FLAGS / ESCALATION
-- ============================================================
create table if not exists moderation_flags (
  id uuid primary key default gen_random_uuid(),
  target_type text not null,
  target_id uuid not null,
  rule_code text not null,
  score numeric(6,4) not null default 0 check(score between 0 and 1),
  evidence jsonb not null default '{}'::jsonb,
  status text not null default 'open' check(status in ('open','reviewed','dismissed','escalated')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists idx_moderation_flags_queue on moderation_flags(status,score desc,created_at asc);

-- ============================================================
-- 4. VERIFICATION: SECOND REVIEW / RE-AUTHENTICATION
-- ============================================================
create table if not exists verification_reviews (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references verification_applications(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete restrict,
  decision text not null check(decision in ('approve','reject','request_more_evidence','escalate')),
  confidence numeric(6,4) not null default 0 check(confidence between 0 and 1),
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_verification_reviews_application on verification_reviews(application_id,created_at desc);

-- ============================================================
-- 5. SCOREBOARD: SEASONS / ROLE LEADERBOARDS
-- ============================================================
create table if not exists scoreboard_seasons (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'scheduled' check(status in ('scheduled','active','completed')),
  created_at timestamptz not null default now(),
  check(ends_at > starts_at)
);
create table if not exists scoreboard_entries (
  season_id uuid not null references scoreboard_seasons(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  score numeric(18,6) not null default 0,
  rank integer,
  momentum numeric(18,6) not null default 0,
  calculated_at timestamptz not null default now(),
  primary key(season_id,user_id,role)
);
create index if not exists idx_scoreboard_entries_rank on scoreboard_entries(season_id,role,rank);

-- ============================================================
-- 6. ANALYTICS: CREATOR DAILY SNAPSHOTS / RETENTION COHORTS
-- ============================================================
create table if not exists creator_daily_snapshots (
  day date not null,
  creator_id uuid not null references auth.users(id) on delete cascade,
  followers integer not null default 0,
  profile_views integer not null default 0,
  content_views integer not null default 0,
  likes integer not null default 0,
  comments integer not null default 0,
  shares integer not null default 0,
  saves integer not null default 0,
  contacts integer not null default 0,
  unique(day,creator_id)
);
create table if not exists retention_cohorts (
  cohort_day date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  day_offset integer not null check(day_offset >= 0),
  retained boolean not null default false,
  unique(cohort_day,user_id,day_offset)
);
create index if not exists idx_creator_snapshots_creator_day on creator_daily_snapshots(creator_id,day desc);
create index if not exists idx_retention_cohort_day on retention_cohorts(cohort_day,day_offset);

-- ============================================================
-- 7. MESSAGING: MESSAGE EDIT / DELETION STATE
-- ============================================================
create table if not exists direct_message_edits (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references direct_messages(id) on delete cascade,
  editor_id uuid not null references auth.users(id) on delete cascade,
  previous_body text,
  edited_body text,
  edited_at timestamptz not null default now()
);
create table if not exists direct_message_deletions (
  message_id uuid not null references direct_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  deleted_for_all boolean not null default false,
  deleted_at timestamptz not null default now(),
  primary key(message_id,user_id)
);
create index if not exists idx_dm_edits_message on direct_message_edits(message_id,edited_at desc);

-- ============================================================
-- RLS
-- ============================================================
alter table story_highlights enable row level security;
alter table story_highlight_items enable row level security;
alter table close_friends enable row level security;
alter table search_history enable row level security;
alter table moderation_flags enable row level security;
alter table verification_reviews enable row level security;
alter table scoreboard_seasons enable row level security;
alter table scoreboard_entries enable row level security;
alter table creator_daily_snapshots enable row level security;
alter table retention_cohorts enable row level security;
alter table direct_message_edits enable row level security;
alter table direct_message_deletions enable row level security;

create policy "Owners manage highlights" on story_highlights for all using(auth.uid()=owner_id) with check(auth.uid()=owner_id);
create policy "Highlight items readable" on story_highlight_items for select using(exists(select 1 from story_highlights h where h.id=highlight_id and h.owner_id=auth.uid()));
create policy "Owners manage highlight items" on story_highlight_items for all using(exists(select 1 from story_highlights h where h.id=highlight_id and h.owner_id=auth.uid())) with check(exists(select 1 from story_highlights h where h.id=highlight_id and h.owner_id=auth.uid()));
create policy "Users manage close friends" on close_friends for all using(auth.uid()=owner_id) with check(auth.uid()=owner_id and owner_id<>friend_id);
create policy "Users manage search history" on search_history for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "Moderation flags staff only" on moderation_flags for select using(has_admin_permission(auth.uid(),'moderation:manage'));
create policy "Moderation flags staff insert" on moderation_flags for insert with check(has_admin_permission(auth.uid(),'moderation:manage'));
create policy "Verification reviews staff only" on verification_reviews for select using(has_admin_permission(auth.uid(),'verification:manage'));
create policy "Verification reviews staff insert" on verification_reviews for insert with check(has_admin_permission(auth.uid(),'verification:manage'));
create policy "Active seasons public" on scoreboard_seasons for select using(status in ('active','completed'));
create policy "Scoreboard public" on scoreboard_entries for select using(exists(select 1 from scoreboard_seasons s where s.id=season_id and s.status in ('active','completed')));
create policy "Creator sees own snapshots" on creator_daily_snapshots for select using(auth.uid()=creator_id);
create policy "Creator sees own retention" on retention_cohorts for select using(auth.uid()=user_id);
create policy "Participants see message edits" on direct_message_edits for select using(exists(select 1 from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id where m.id=message_id and p.user_id=auth.uid()));
create policy "Participants create own message edits" on direct_message_edits for insert with check(auth.uid()=editor_id and exists(select 1 from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id where m.id=message_id and p.user_id=auth.uid()));
create policy "Users manage message deletion state" on direct_message_deletions for all using(auth.uid()=user_id) with check(auth.uid()=user_id and exists(select 1 from direct_messages m join direct_conversation_participants p on p.conversation_id=m.conversation_id where m.id=message_id and p.user_id=auth.uid()));

commit;
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
-- FUSKAMO Status Notes
-- Additive migration: adds a lightweight ephemeral text-status ("note")
-- variant onto the existing social_stories table instead of a new table,
-- so notes and media stories share expiry/read-tracking logic.

alter table social_stories
  alter column media_url drop not null;

alter table social_stories
  drop constraint if exists social_stories_media_type_check;

alter table social_stories
  add constraint social_stories_media_type_check
  check (media_type in ('image','external_video','note'));

alter table social_stories
  add constraint social_stories_note_shape_check
  check (
    (media_type = 'note' and media_url is null and char_length(trim(caption)) between 1 and 60)
    or
    (media_type <> 'note' and media_url is not null)
  );

-- Notes expire faster than media stories (2h vs 24h, matching the "what's
-- up right now" framing). The table default stays 24h for media stories;
-- the app sets expires_at explicitly to +2h when media_type='note'.
