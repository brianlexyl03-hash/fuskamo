#!/usr/bin/env bash
# Real database backup via pg_dump against Supabase's own Postgres
# connection string. Supabase's free tier also takes automatic daily
# backups (visible in the project dashboard, Database > Backups) — this
# script is for an on-demand/local copy in addition to that, e.g. right
# before running a risky migration.
set -euo pipefail

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump not found. Install the Postgres client tools first:" >&2
  echo "  Debian/Ubuntu/Termux: apt install postgresql-client" >&2
  echo "  macOS: brew install postgresql" >&2
  exit 1
fi

if [ -z "${SUPABASE_DB_URL:-}" ]; then
  echo "SUPABASE_DB_URL is not set. Export it first (same value as backend/.env):" >&2
  echo "  export SUPABASE_DB_URL='postgresql://...'" >&2
  exit 1
fi

OUT_DIR="$(dirname "$0")/../backups"
mkdir -p "$OUT_DIR"
STAMP=$(date -u +"%Y%m%dT%H%M%SZ")
OUT_FILE="$OUT_DIR/fuskamo_${STAMP}.sql.gz"

echo "Backing up to $OUT_FILE ..."
pg_dump "$SUPABASE_DB_URL" --no-owner --no-privileges | gzip > "$OUT_FILE"
echo "Done: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
echo ""
echo "This file contains your full database, including user data — treat it"
echo "like any other secret. It is gitignored; do not commit it."
