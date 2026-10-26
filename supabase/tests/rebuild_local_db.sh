#!/usr/bin/env bash
# =====================================================================
# Rebuild the throwaway LOCAL test database as a copy of production
# today: every migration in supabase/migrations/, then real data from
# a backup taken after the last migration.
#
# Usage:  supabase/tests/rebuild_local_db.sh backups/2026-10-26 [db_name]
# Needs:  a local Postgres 16+ with PostGIS, listening on PGHOST/PGPORT
#         (defaults: socket in /tmp, port 54329).
# =====================================================================
set -euo pipefail

BACKUP_DIR="$1"
DB="${2:-yvr_test}"
PSQL="psql -h ${PGHOST:-/tmp} -p ${PGPORT:-54329} -U postgres -v ON_ERROR_STOP=1 -q"

$PSQL -c "drop database if exists $DB" -c "create database $DB"

apply() {
  echo "applying $1"
  PGOPTIONS="-c client_min_messages=warning" $PSQL -d "$DB" -f "$1"
}

apply supabase/tests/00_local_supabase_standins.sql
apply supabase/migrations/20241015120000_core_schema.sql
apply supabase/migrations/20260302000000_drop_sub_ratings.sql
# a policy that existed live before October but is in no migration
apply supabase/tests/01_match_live_before_october.sql

# every later migration, in version order
for f in supabase/migrations/*.sql; do
  case "$f" in
    *20241015120000_core_schema.sql|*20260302000000_drop_sub_ratings.sql) continue ;;
  esac
  apply "$f"
done

supabase/tests/load_backup.sh "$BACKUP_DIR" "$DB"
