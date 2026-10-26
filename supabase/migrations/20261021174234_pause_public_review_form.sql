-- =====================================================================
-- 2026-10-20  Pause the public review form
-- ---------------------------------------------------------------------
-- Decided 2026-10-20: switch the public form off until the review
-- pipeline is finished. Hiding the page is not enough, because
-- anyone with the public key could still add rows through the API. So
-- the database itself now only accepts new reviews from admins.
--
-- To switch the public form back on later, run the "undo" block at the
-- bottom of this file as a new migration.
-- Depends on: 20261006_security_fixes.sql (creates reviews_insert).
-- =====================================================================

drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews for insert
  with check ((select public.is_admin()));

-- anon never needs to write anything now
revoke insert on public.reviews from anon;


-- ---------------------------------------------------------------------
-- UNDO (switch the public form back on): copy into a new migration
-- ---------------------------------------------------------------------
-- grant insert on public.reviews to anon;
-- drop policy if exists reviews_insert on public.reviews;
-- create policy reviews_insert on public.reviews for insert
--   with check ((status = 'pending' and author_type = 'public') or (select public.is_admin()));
