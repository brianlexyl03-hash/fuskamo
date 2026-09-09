-- Performance indexes found missing during a full production audit.
-- None of these change behavior — every query these support already
-- works, they just table-scan without the index below.

-- saved_players.player_id had no index at all (only user_id did, via the
-- composite primary key). Needed for "who saved this player" and for the
-- planner to use an index rather than a full scan on the cascade delete
-- from players.
create index if not exists idx_saved_players_player on saved_players(player_id);

-- notifications was indexed on (user_id, read) but the actual notification
-- feed query orders by created_at desc — add it to the index so that sort
-- doesn't happen in memory on every load.
create index if not exists idx_notifications_user_created on notifications(user_id, created_at desc);

-- ai_usage_logs had no index at all — fine at low volume, but any cost
-- reporting/date-range query (docs/production-checklist.md's AI cost
-- tracking) will table-scan the whole log without this once it grows.
create index if not exists idx_ai_usage_logs_created on ai_usage_logs(created_at desc);
