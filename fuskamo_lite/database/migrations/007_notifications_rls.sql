-- 005_notifications.sql created these tables without RLS. That's fine as
-- long as only the backend's service-role client ever touches them, but
-- notification_provider.dart / notification_service.dart now read
-- `notifications` directly from Flutter with the anon key — so RLS has to
-- actually scope rows to their owner before that's safe.
alter table notifications enable row level security;
alter table notification_preferences enable row level security;

-- Read/mark-read only — inserts stay backend-only (service role bypasses
-- RLS entirely), matching notificationRepository.js's comment that rows
-- are always written server-side.
create policy "Users read their own notifications" on notifications
  for select using (auth.uid() = user_id);

create policy "Users mark their own notifications read" on notifications
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users manage their own notification preferences" on notification_preferences
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
