-- Backs the "boost submission" M-Pesa flow: a player row featured until
-- this timestamp sorts first in the feed (see PlayerService.fetchApprovedPlayers
-- in the Flutter app, which orders by featured_until first).
alter table players add column if not exists featured_until timestamptz;

create index if not exists idx_players_featured on players(featured_until);
