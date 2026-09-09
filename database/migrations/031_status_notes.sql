-- FUSKAMO Status Notes
-- Additive migration: adds a lightweight ephemeral text-status ("note")
-- variant onto the existing social_stories table instead of a new table,
-- so notes and media stories share expiry/read-tracking logic.

alter table social_stories
  alter column media_url drop not null;

alter table social_stories
  drop constraint if exists social_stories_media_type_check;

alter table social_stories
  add constraint social_stories_media_type_check
  check (media_type in ('image','external_video','note'));

alter table social_stories
  add constraint social_stories_note_shape_check
  check (
    (media_type = 'note' and media_url is null and char_length(trim(caption)) between 1 and 60)
    or
    (media_type <> 'note' and media_url is not null)
  );

-- Notes expire faster than media stories (2h vs 24h, matching the "what's
-- up right now" framing). The table default stays 24h for media stories;
-- the app sets expires_at explicitly to +2h when media_type='note'.
