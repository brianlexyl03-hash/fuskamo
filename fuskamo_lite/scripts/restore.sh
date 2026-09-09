#!/usr/bin/env bash
# Restores a backup made by backup.sh. This is DESTRUCTIVE — it applies
# directly to whatever SUPABASE_DB_URL points at. Point it at a fresh/
# scratch Supabase project when testing this, never your production
# project, unless you specifically intend to overwrite production.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-backup.sql.gz>" >&2
  exit 1
fi
BACKUP_FILE="$1"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql not found. Install the Postgres client tools first:" >&2
  echo "  Debian/Ubuntu/Termux: apt install postgresql-client" >&2
  echo "  macOS: brew install postgresql" >&2
  exit 1
fi
if [ ! -f "$BACKUP_FILE" ]; then
  echo "No such file: $BACKUP_FILE" >&2
  exit 1
fi
if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "SUPABASE_DB_URL is not set. Export it first:" >&2
  echo "  export SUPABASE_DB_URL='postgresql://...'" >&2
  exit 1
fi

echo "About to restore $BACKUP_FILE into:"
echo "  $SUPABASE_DB_URL"
read -p "This will overwrite existing data. Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

gunzip -c "$BACKUP_FILE" | psql "$SUPABASE_DB_URL"
echo "Restore complete. Now verify the app actually works against it —"
echo "a restore that runs without error is not the same as a working app."
