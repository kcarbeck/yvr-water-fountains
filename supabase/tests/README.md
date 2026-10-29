# Database tests

Files for checking database changes before they touch production.

| File | What it does | Safe on production? |
|---|---|---|
| `rls_matrix.sql` | Tries every action as a visitor, a logged-in user and an admin, and prints PASS/FAIL against the expected access rules | Yes. Every write is undone and the file ends in ROLLBACK. Set `admin_id` at the top to the real admin's user id first. |
| `public_review_functions.sql` | Calls `submit_public_review()` and `submit_report()` as a visitor and checks each refusal gives the expected message | Yes. Ends in ROLLBACK. |
| `visit_date_order.sql` | Adds three reviews to one fountain and checks the latest rating is the newest visit, not the newest approval, and that an open maintenance issue stays open until an admin clears it | Yes. Ends in ROLLBACK. |
| `view_equivalence.sql` | What the public map sees in `fountain_overview_view`: row count, rated rows, rating sum, set of Instagram links | Yes (read-only) |
| `checksums.sql` | One fingerprint per table, to prove two databases hold identical data | Yes (read-only) |
| `schema_fingerprint.sql` | Fingerprints of policies, grants, views, functions and indexes, to prove a rollback restored the old rules | Yes (read-only) |
| `00_local_supabase_standins.sql` | Adds the bits Supabase normally provides (roles, `auth.uid()`) to a plain local Postgres | No. Local only. |
| `01_match_live_before_october.sql` | One policy that exists live but in no migration file | No. Local only. |
| `rebuild_local_db.sh`, `load_backup.sh` | Build a throwaway local copy of production from a backup folder. Loads admins too when the folder has `admins.json`. | Local only |

## Typical local test

```bash
# a local Postgres 16+ with PostGIS on port 54329
supabase/tests/rebuild_local_db.sh backups/2026-10-26 yvr_test
psql -h /tmp -p 54329 -U postgres -d yvr_test -f supabase/tests/rls_matrix.sql
psql -h /tmp -p 54329 -U postgres -d yvr_test -f supabase/tests/view_equivalence.sql
```

Every migration and data fix has a matching file in `supabase/rollbacks/`.
