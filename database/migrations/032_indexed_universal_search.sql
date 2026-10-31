-- FUSKAMO migration 032: indexed universal search.
-- The existing search_fuskamo_v2 RPC uses substring predicates. pg_trgm
-- GIN indexes make those predicates index-supported rather than full scans.

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

create index if not exists profiles_username_trgm_idx
  on public.profiles using gin (lower(coalesce(username, '')) extensions.gin_trgm_ops);
create index if not exists profiles_display_name_trgm_idx
  on public.profiles using gin (lower(coalesce(display_name, '')) extensions.gin_trgm_ops);
create index if not exists groups_name_trgm_idx
  on public.groups using gin (lower(coalesce(name, '')) extensions.gin_trgm_ops);
create index if not exists groups_description_trgm_idx
  on public.groups using gin (lower(coalesce(description, '')) extensions.gin_trgm_ops);
create index if not exists social_posts_body_trgm_idx
  on public.social_posts using gin (lower(coalesce(body, '')) extensions.gin_trgm_ops);
create index if not exists social_reels_caption_trgm_idx
  on public.social_reels using gin (lower(coalesce(caption, '')) extensions.gin_trgm_ops);
create index if not exists players_name_trgm_idx
  on public.players using gin (lower(coalesce(name, '')) extensions.gin_trgm_ops);
create index if not exists scouts_name_trgm_idx
  on public.scouts using gin (lower(coalesce(name, '')) extensions.gin_trgm_ops);

comment on index public.profiles_username_trgm_idx is 'Supports substring username search in search_fuskamo_v2';
comment on index public.profiles_display_name_trgm_idx is 'Supports substring display-name search in search_fuskamo_v2';
comment on index public.groups_name_trgm_idx is 'Supports substring group-name search in search_fuskamo_v2';
comment on index public.groups_description_trgm_idx is 'Supports substring group-description search in search_fuskamo_v2';
comment on index public.social_posts_body_trgm_idx is 'Supports substring post-body search in search_fuskamo_v2';
comment on index public.social_reels_caption_trgm_idx is 'Supports substring reel-caption search in search_fuskamo_v2';
comment on index public.players_name_trgm_idx is 'Supports substring player-name search in search_fuskamo_v2';
comment on index public.scouts_name_trgm_idx is 'Supports substring scout-name search in search_fuskamo_v2';
