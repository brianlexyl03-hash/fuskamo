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
