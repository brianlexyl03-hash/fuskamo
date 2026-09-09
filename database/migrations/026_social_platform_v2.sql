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
