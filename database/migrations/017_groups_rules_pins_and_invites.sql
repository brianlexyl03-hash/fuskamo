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
