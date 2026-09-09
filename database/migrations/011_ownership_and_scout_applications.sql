-- Links a submission back to the account that made it — needed for "My
-- Submissions" (Profile screen), the boost-payment notification that
-- previously had nowhere to send, and the new approve/reject
-- notifications in playerAdminRepository.js. Nullable: submitting a player
-- has never required signing in, so older/anonymous rows simply have no
-- owner and won't show up in anyone's "My Submissions" list.
alter table players add column if not exists submitted_by uuid references auth.users(id);
create index if not exists idx_players_submitted_by on players(submitted_by);

create policy "Owners can view their own submissions" on players
  for select using (auth.uid() = submitted_by);

-- Scout applications: reuses `verified` as the review flag (false =
-- pending, true = listed) instead of adding a parallel status column.
-- user_id is nullable for the same reason as players.submitted_by above.
--
-- Correction: an earlier round of work claimed scouts had no RLS at all
-- and "fixed" that here — that was wrong. 001_players_scouts.sql already
-- ran `alter table scouts enable row level security` and created the
-- "Public can view verified scouts" policy. Re-declaring either of those
-- here would fail with a duplicate-policy error on a fresh database, so
-- this migration only adds what 001 didn't already cover: the insert
-- policy for applications, and owners viewing their own (unverified) row.
alter table scouts add column if not exists user_id uuid references auth.users(id);
create index if not exists idx_scouts_user_id on scouts(user_id);

create policy "Anyone can apply as a scout" on scouts
  for insert with check (verified = false);

create policy "Owners can view their own scout application" on scouts
  for select using (auth.uid() = user_id);
