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
