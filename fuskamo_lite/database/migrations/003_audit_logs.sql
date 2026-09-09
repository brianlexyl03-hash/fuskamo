create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor text not null, action text not null,
  target_type text not null, target_id text not null,
  metadata jsonb default '{}', created_at timestamptz default now()
);
create index if not exists idx_audit_logs_target on audit_logs(target_type, target_id);
