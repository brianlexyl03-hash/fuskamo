-- Backs the real "save player" bookmark (was a fake toast before this —
-- see lib/widgets/player_card.dart / lib/providers/saved_players_provider.dart).
-- Requires being signed in — see AuthProvider — since a save is tied to a user.
create table if not exists saved_players (
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id uuid not null references players(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, player_id)
);

alter table saved_players enable row level security;

create policy "Users manage their own saved players" on saved_players
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_saved_players_user on saved_players(user_id, created_at desc);
