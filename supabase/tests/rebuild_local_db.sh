#!/usr/bin/env bash
# =====================================================================
# Rebuild the throwaway LOCAL test database as a copy of production
# "before the October fixes", loaded with real data from a backup.
#
# Usage:  supabase/tests/rebuild_local_db.sh backups/2026-10-20 [db_name]
# Needs:  a local Postgres 16+ with PostGIS, listening on PGHOST/PGPORT
#         (defaults: socket in /tmp, port 54329).
# =====================================================================
set -euo pipefail

BACKUP_DIR="$1"
DB="${2:-yvr_test}"
PSQL="psql -h ${PGHOST:-/tmp} -p ${PGPORT:-54329} -U postgres -v ON_ERROR_STOP=1 -q"

$PSQL -c "drop database if exists $DB" -c "create database $DB"

for f in supabase/tests/00_local_supabase_standins.sql \
         supabase/migrations/20241015120000_core_schema.sql \
         supabase/migrations/20260302_drop_sub_ratings.sql \
         supabase/tests/01_match_live_before_october.sql; do
  echo "applying $f"
  PGOPTIONS="-c client_min_messages=warning" $PSQL -d "$DB" -f "$f"
done

supabase/tests/load_backup.sh "$BACKUP_DIR" "$DB"
