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
