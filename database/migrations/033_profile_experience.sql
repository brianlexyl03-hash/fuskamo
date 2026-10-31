-- Profile experience fields used by the native and web profile editors.
-- Safe to re-run; rollback is documented below.
begin;

alter table public.profiles
  add column if not exists pronouns text,
  add column if not exists gender text,
  add column if not exists profile_category text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='profiles_pronouns_length_check' and conrelid='public.profiles'::regclass) then
    alter table public.profiles add constraint profiles_pronouns_length_check check (pronouns is null or char_length(pronouns) <= 40);
  end if;
  if not exists (select 1 from pg_constraint where conname='profiles_gender_allowed_check' and conrelid='public.profiles'::regclass) then
    alter table public.profiles add constraint profiles_gender_allowed_check check (gender is null or gender in ('male','female','non_binary','custom'));
  end if;
  if not exists (select 1 from pg_constraint where conname='profiles_profile_category_allowed_check' and conrelid='public.profiles'::regclass) then
    alter table public.profiles add constraint profiles_profile_category_allowed_check check (profile_category is null or profile_category in ('player','coach','scout','club','creator'));
  end if;
end $$;

comment on column public.profiles.pronouns is 'Optional pronouns displayed on the public profile.';
comment on column public.profiles.gender is 'Optional self-described gender selection; not used for ranking or discovery.';
comment on column public.profiles.profile_category is 'Optional public-facing profile category.';

commit;

-- Rollback:
-- begin;
-- alter table public.profiles drop constraint if exists profiles_pronouns_length_check;
-- alter table public.profiles drop constraint if exists profiles_gender_allowed_check;
-- alter table public.profiles drop constraint if exists profiles_profile_category_allowed_check;
-- alter table public.profiles drop column if exists pronouns, drop column if exists gender, drop column if exists profile_category;
-- commit;
