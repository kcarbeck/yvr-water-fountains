-- ROLLBACK for supabase/pending/unique_instagram_links.sql
drop index if exists public.reviews_instagram_url_key;
