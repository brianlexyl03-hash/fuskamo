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
