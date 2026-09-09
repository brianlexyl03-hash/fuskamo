No websocket/real-time layer yet. Supabase Realtime (built on Postgres
logical replication) already gives you live feed updates for free without
running your own socket server — prefer that over adding Socket.io here
unless you hit a case Supabase Realtime genuinely can't cover.
