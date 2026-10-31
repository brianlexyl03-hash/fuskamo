-- Profile presentation and creator customization fields.
begin;

alter table public.profiles
  add column if not exists pronouns text not null default '' check (char_length(pronouns) <= 40),
  add column if not exists gender text not null default '' check (char_length(gender) <= 40),
  add column if not exists profile_category text not null default '' check (char_length(profile_category) <= 60),
  add column if not exists profile_links jsonb not null default '[]'::jsonb check (jsonb_typeof(profile_links) = 'array'),
  add column if not exists profile_display jsonb not null default '{}'::jsonb check (jsonb_typeof(profile_display) = 'object'),
  add column if not exists ai_generated_profile boolean not null default false;

create table if not exists public.profile_banners (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 40),
  subtitle text not null default '' check (char_length(subtitle) <= 100),
  media_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists profile_banners_owner_sort on public.profile_banners(owner_id, sort_order, created_at);
alter table public.profile_banners enable row level security;
drop policy if exists "Profile banners are publicly readable" on public.profile_banners;
create policy "Profile banners are publicly readable" on public.profile_banners for select using (true);
drop policy if exists "Users manage their own profile banners" on public.profile_banners;
create policy "Users manage their own profile banners" on public.profile_banners for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

commit;
