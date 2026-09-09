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
