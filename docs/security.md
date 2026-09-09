# Security

- Row-Level Security (RLS) enabled on all Supabase tables (`database/migrations/`) — the Supabase anon key embedded in the app is safe to ship; RLS is what actually restricts access, not key secrecy.
- Real Supabase keys live only in `.env` (gitignored) — never hardcoded in `lib/config/`.
- Signing keystores (`release/keystore/`) are gitignored and must never be committed — losing this file means you can never update your Play Store listing under the same app, so back it up securely outside git.
- Player submissions default to `pending` and are never publicly queryable until approved.
- No real personal data (names, ages, countries of real people) is hardcoded anywhere in `lib/` — every Player/Scout instance is constructed from a live Supabase row.
