-- Backs PushNotificationService (lib/notifications/push_notification_service.dart).
-- One row per device/token; a user can have several (phone + tablet).
create table if not exists device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios','android')),
  updated_at timestamptz not null default now()
);

alter table device_tokens enable row level security;

-- Users manage only their own device rows; the backend's service-role key
-- (used to actually send pushes) bypasses RLS entirely, same as it does
-- for notifications — see backend/src/services.
create policy "Users manage their own device tokens" on device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_device_tokens_user on device_tokens(user_id);
