-- ROLLBACK for supabase/migrations/20261026013623_unique_instagram_links.sql
drop index if exists public.reviews_instagram_url_key;
