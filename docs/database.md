# Database

Postgres via Supabase — schema evolved across 14 numbered migrations (see `database/migrations/`), now consumed by Dart's `Player`/`Scout` models (`lib/models/`) instead of JS objects.

## Tables (MVP)
- `players` — id, name, position, age, country, club, strengths, video_url, status, jersey_number, created_at
- `scouts` — id, name, organization, badge_type, verified, created_at

Row-level security is unchanged from the web version: public reads restricted to approved players / verified scouts; inserts to `players` locked to `status = 'pending'`.
