# Backup and restore

## Automatic (does nothing you need to set up)

Supabase takes automatic backups of your project's database on your
behalf — daily on the free tier, point-in-time recovery on paid tiers.
Nothing in this repo needs to run for that to happen. Check your actual
retention window in the project dashboard: Database → Backups.

**This is genuinely sufficient for most of this project's life.** The
scripts below are for the specific moments that benefit from a manual,
on-demand copy — right before a risky migration, or before a bulk data
change you might want to undo quickly without waiting on Supabase's own
restore flow.

## Manual on-demand backup

```bash
export SUPABASE_DB_URL='postgresql://...'   # Project Settings → Database → Connection string
./scripts/backup.sh
```

Requires the Postgres client tools (`pg_dump`) — not a Node/npm
dependency, install separately (`apt install postgresql-client` on
Debian/Ubuntu/Termux, `brew install postgresql` on macOS). Writes a
timestamped, gzip-compressed `.sql.gz` file to `backups/` (gitignored —
never commit one, it contains real user data).

## Restore

```bash
export SUPABASE_DB_URL='postgresql://...'   # point this at a SCRATCH project when testing
./scripts/restore.sh backups/fuskamo_20260101T000000Z.sql.gz
```

This is destructive — it overwrites whatever `SUPABASE_DB_URL` currently
points at. The script asks for an explicit `yes` confirmation before
running.

## Testing the full loop (do this before you actually need it to work)

1. Create a second, throwaway Supabase project (Free tier is fine).
2. `export SUPABASE_DB_URL` pointed at your **real** project, run
   `./scripts/backup.sh`.
3. `export SUPABASE_DB_URL` pointed at the **throwaway** project instead,
   run `./scripts/restore.sh <the file from step 2>`.
4. Point a local copy of the backend's `.env` at the throwaway project's
   URL/keys and run `npm start`, then `curl localhost:8080/api/ready` —
   it should report `supabase: true`.
5. Spot-check a few real rows exist (`select count(*) from players;` via
   `psql` or the Supabase SQL Editor on the throwaway project).

A restore that completes without a shell error is not the same as a
database your app can actually run against — step 4 is the part that
actually proves the backup is good, not step 3.

## What backup.sh does NOT cover

Supabase Storage (uploaded videos/images) isn't included in a `pg_dump` —
that's object storage, not the Postgres database. For those, use
Supabase's own Storage backup/export tooling if you need it; this repo's
scripts are database-only.
