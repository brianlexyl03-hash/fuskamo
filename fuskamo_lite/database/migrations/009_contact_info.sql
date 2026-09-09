-- Real "Contact" buttons need something to contact. Neither players nor
-- scouts had any contact field before this — CONTACT on a player card was
-- a fake toast with nowhere to actually send anything (see
-- lib/widgets/player_card.dart). Both optional: submitters aren't forced
-- to expose contact info, and the app degrades honestly (an explicit
-- "no contact info on file" state, not a fake success message) when it's
-- missing.
alter table players add column if not exists contact_email text;
alter table players add column if not exists contact_phone text;
alter table scouts add column if not exists contact_email text;
alter table scouts add column if not exists contact_phone text;
