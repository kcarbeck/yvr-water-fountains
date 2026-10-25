-- =====================================================================
-- One Instagram post = one review, enforced by the database
-- =====================================================================
-- After this, adding a second review with the same Instagram link fails
-- with an error instead of silently creating a duplicate. Reviews with
-- no link are not affected.
-- Needs: supabase/data_fixes/2026-10-06_review_link_fixes.sql applied
-- first (step A3 clears the one link that is currently used twice).
-- Rollback: supabase/rollbacks/rollback_unique_instagram_links.sql
-- =====================================================================

create unique index if not exists reviews_instagram_url_key
  on public.reviews (instagram_url)
  where instagram_url is not null;
