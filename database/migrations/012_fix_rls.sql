-- Fixes the 3 CRITICAL "RLS Disabled in Public" findings from the
-- Supabase security advisor. These tables are written/read only by the
-- backend via the service_role key (which bypasses RLS entirely), so we
-- just lock them down with no public policies -- nothing else should
-- ever query them directly.
alter table transactions enable row level security;
alter table audit_logs enable row level security;
alter table ai_usage_logs enable row level security;
