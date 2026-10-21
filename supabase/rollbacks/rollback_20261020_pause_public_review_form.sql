-- =====================================================================
-- ROLLBACK for supabase/migrations/20261020_pause_public_review_form.sql
-- Switches the public review form back on at the database level
-- (state right after 20261006_security_fixes.sql).
-- =====================================================================
begin;

grant insert on public.reviews to anon;

drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews for insert
  with check ((status = 'pending' and author_type = 'public') or (select public.is_admin()));

commit;
