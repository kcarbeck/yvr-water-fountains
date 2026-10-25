-- =====================================================================
-- Local test database only.
-- ---------------------------------------------------------------------
-- Things that exist in the live database (checked 2026-10-20) but are
-- not in any migration file. Adding them here makes the local copy
-- match production before the October fixes are tested.
-- =====================================================================

-- live has this extra policy on admins (added by hand at some point)
create policy admins_read_own on public.admins
for select using (user_id = auth.uid());
