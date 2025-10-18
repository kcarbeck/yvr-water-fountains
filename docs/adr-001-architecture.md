# adr 001: simplify data shape while keeping supabase

## decision
we continue using supabase (postgres) with supabase-js on the client. the data model is trimmed to four core tables plus a dedicated admins table so moderation stays explicit.

## data model
- **cities**: each supported municipality so future regional data can live side by side.
- **sources**: provenance for fountain records (manual admin entry, open data import, etc.).
- **fountains**: canonical fountain metadata including location, operational state, season notes, pet friendly flag, and source references.
- **reviews**: public and admin reviews with status, rating, instagram url, and optional image metadata.
- **admins**: supabase-managed user records allowed to approve reviews and add admin-only notes.

## supporting views
- **fountain_ratings_view**: exposes each fountain with its rolling average rating calculated across approved reviews.
- **fountain_latest_review_view**: exposes the most recent approved review text, rating, instagram link, and related image.

## row level security
- public users can read fountains, cities, sources, and both views.
- public users can insert reviews flagged as `status = 'pending'` and only read reviews where `status = 'approved'`.
- admins can insert approved reviews directly, update pending reviews to approved, and manage fountain metadata.

## rationale
- we already rely on supabase; staying put avoids a platform migration.
- supabase has clear documentation, hosted postgres, and built-in auth, so this is the lowest-risk path.
- simplifying to these tables clarifies ownership and reduces redundant columns we previously carried across multiple data files.
- views keep read logic simple for the frontend while letting the database own the aggregation rules.
- rls keeps review moderation enforceable even if someone inspects network calls.

## next steps (separate prs)
1. **schema migration**: define sql migrations for the new tables, views, and rls policies under `supabase/migrations/`.
2. **data backfill**: write scripts to migrate existing fountain and review data into the new structure, preserving ids when possible.
3. **frontend update**: refactor `docs/js/` to pull from the new views using supabase-js, simplifying the client data transforms.
4. **moderation ui**: build a gated admin page that lists pending reviews and allows approve/deny actions using the admins table.
