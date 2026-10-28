#!/usr/bin/env bash
# =====================================================================
# Load a backup folder into a LOCAL test database.
# Never point this at Supabase.
#
# Usage:  supabase/tests/load_backup.sh backups/2026-10-26 yvr_test
# =====================================================================
set -euo pipefail

BACKUP_DIR="$1"          # folder with cities.json, sources.json, fountains.json, reviews.json
DB="$2"                  # local database name
PSQL="psql -h ${PGHOST:-/tmp} -p ${PGPORT:-54329} -U postgres -v ON_ERROR_STOP=1 -q -d $DB"

# one fake admin user so admin tests have someone to log in as
$PSQL -c "insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000a0a0', 'admin@test.local') on conflict do nothing;"
$PSQL -c "insert into public.admins (user_id, display_name) values ('00000000-0000-0000-0000-00000000a0a0', 'test admin') on conflict do nothing;"
# and one ordinary logged-in user
$PSQL -c "insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000b0b0', 'user@test.local') on conflict do nothing;"

# the real admins too, when the backup has them: an approved review
# points at the admin who approved it (reviews.approved_by)
if [ -f "$BACKUP_DIR/admins.json" ]; then
  $PSQL <<SQL
\set json \`cat "$BACKUP_DIR/admins.json"\`
insert into auth.users (id, email)
  select user_id, user_id::text || '@test.local' from json_populate_recordset(null::public.admins, :'json')
  on conflict do nothing;
insert into public.admins select * from json_populate_recordset(null::public.admins, :'json') on conflict do nothing;
SQL
fi

# tables in dependency order; json_populate_recordset matches JSON keys to column names
for table in cities sources fountains reviews; do
  # psql reads the file into the variable "json", then inserts every row
  $PSQL <<SQL
\set json \`cat "$BACKUP_DIR/$table.json"\`
insert into public.$table select * from json_populate_recordset(null::public.$table, :'json');
SQL
  echo "loaded $table: $($PSQL -tA -c "select count(*) from public.$table")"
done
