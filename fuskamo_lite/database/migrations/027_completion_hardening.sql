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
