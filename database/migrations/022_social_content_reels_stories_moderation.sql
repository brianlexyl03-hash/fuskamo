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
