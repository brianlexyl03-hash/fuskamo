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
