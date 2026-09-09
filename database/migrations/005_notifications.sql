create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null, title text not null, body text, type text,
  read boolean default false, created_at timestamptz default now()
);
create table if not exists notification_preferences (
  user_id uuid primary key,
  sms_enabled boolean default true, email_enabled boolean default true, push_enabled boolean default true
);
create index if not exists idx_notifications_user on notifications(user_id, read);
