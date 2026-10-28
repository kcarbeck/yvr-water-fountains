# Database changes

Everything that changes the live Supabase database (project `hnyktzfyquvmpthfwpvd`) is kept here as a file, so the repo always shows what the database looks like.

## Folders

- `migrations/`: schema changes that are **on the live database**. Each file name starts with the version recorded in the database's migration history (`supabase_migrations.schema_migrations`), so the folder and the history always match.
- `pending/`: schema changes that are written and tested but **not applied yet**. When one is applied, it moves to `migrations/` and is renamed to the version Supabase records.
- `data_fixes/`: one-time corrections to the data (not the schema). The status table below says which have been run.
- `rollbacks/`: how to undo each migration or data fix.
- `tests/`: checks run before and after every change (access rules, the public map view, row counts and checksums), and scripts to rebuild a throwaway local copy.

## Rules

1. Test on a local copy first, then show the exact SQL and the before/after numbers, and get Katherine's OK before anything runs on the live database.
2. Apply schema changes with Supabase's migration tool (so they are recorded), never by pasting SQL into the dashboard.
3. After applying, rename the file to the recorded version and update the table below in the same pull request.

## Status

| File | What it does | On the live database |
|---|---|---|
| `migrations/20241015120000_core_schema.sql` | Original tables, views and access rules | Yes, applied by hand in 2024; recorded in the history on 2026-10-25 |
| `migrations/20260302000000_drop_sub_ratings.sql` | Removes the five unused sub-rating columns | Yes, applied by hand in March 2026; recorded in the history on 2026-10-25 |
| `migrations/20261021173926_security_fixes.sql` | Fixes access rules; hides reviewer emails | Yes, 2026-10-21 |
| `migrations/20261021174234_pause_public_review_form.sql` | Only admins can add reviews | Yes, 2026-10-21 |
| `migrations/20261026013441_add_is_indoor.sql` | Adds an "indoor" label to fountains | Yes, 2026-10-25 |
| `migrations/20261026013623_unique_instagram_links.sql` | Stops the same Instagram post being added twice | Yes, 2026-10-25 |
| `migrations/20261027000642_public_reviews.sql` | Settings switch, public review and report functions, reports table, `reviews.created_by`, admin/public rating columns on the map views | Yes, 2026-10-26 |
| `data_fixes/2026-10-06_review_link_fixes.sql` | Corrects reviews linked to the wrong fountain; adds the two 2025 links | Yes, 2026-10-25 |
| `data_fixes/2026-10-20_repair_garbled_emoji.sql` | Repairs garbled emoji in 4 captions | Yes, 2026-10-25 |
| `data_fixes/2026-10-25_backlog_import.sql` | Adds the 17 backlog posts and 11 new fountains | Yes, 2026-10-25 |
| `pending/fountain_info.sql` | Latest review by visit date; `anti_freeze` and `status_reported_at` on fountains; the three detail columns on reviews; `fountain_reviews_view` for the all-visits list; `submit_public_review` takes the details | No |
| `pending/postgis_nearest_fountains.sql` | PostGIS and the "nearest fountains" function | No |

The five 2026-10-25 changes were applied in this order: add_is_indoor, review_link_fixes, repair_garbled_emoji, unique_instagram_links, backlog_import. Roll back in the reverse order.
Each step was rehearsed on a copy of the live data on 2026-10-25: after the five rollbacks the data and the access rules were identical to the start.
