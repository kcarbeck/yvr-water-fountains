-- Phase 1: Drop unused sub-rating columns from reviews.
-- All 42 existing reviews use only the single `rating` column.
-- The 5 sub-rating columns were never populated by the Instagram backfill tool.
--
-- Views must be dropped first because the lateral join uses SELECT *,
-- which creates a dependency on all columns.

-- 1. Drop dependent views (order matters: overview depends on latest_review and ratings)
DROP VIEW IF EXISTS public.fountain_overview_view;
DROP VIEW IF EXISTS public.fountain_latest_review_view;
DROP VIEW IF EXISTS public.fountain_ratings_view;

-- 2. Drop the sub-rating columns
ALTER TABLE public.reviews
  DROP COLUMN IF EXISTS water_quality,
  DROP COLUMN IF EXISTS flow_pressure,
  DROP COLUMN IF EXISTS temperature,
  DROP COLUMN IF EXISTS cleanliness,
  DROP COLUMN IF EXISTS accessibility;

-- 3. Recreate views (identical to originals — they never referenced sub-ratings)
CREATE OR REPLACE VIEW public.fountain_ratings_view AS
SELECT
  f.id AS fountain_id,
  round(avg(r.rating)::numeric, 2) AS average_rating,
  count(r.*) FILTER (WHERE r.status = 'approved') AS approved_review_count,
  count(r.*) FILTER (WHERE r.status = 'approved' AND r.author_type = 'admin') AS admin_review_count
FROM public.fountains f
LEFT JOIN public.reviews r ON r.fountain_id = f.id AND r.status = 'approved'
GROUP BY f.id;

CREATE OR REPLACE VIEW public.fountain_latest_review_view AS
SELECT
  f.id AS fountain_id,
  r.id AS review_id,
  r.review_text,
  r.rating,
  r.instagram_url,
  r.instagram_image_url,
  r.instagram_caption,
  r.author_type,
  r.reviewer_name,
  coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) AS reviewed_at,
  r.created_at
FROM public.fountains f
LEFT JOIN LATERAL (
  SELECT *
  FROM public.reviews r
  WHERE r.fountain_id = f.id
    AND r.status = 'approved'
  ORDER BY coalesce(r.reviewed_at, r.visit_date::timestamptz, r.created_at) DESC
  LIMIT 1
) r ON true;

CREATE OR REPLACE VIEW public.fountain_overview_view AS
SELECT
  f.id,
  f.external_id,
  f.name,
  f.neighbourhood,
  f.location_description,
  f.latitude,
  f.longitude,
  f.operational_status,
  f.season_note,
  f.pet_friendly,
  f.has_bottle_filler,
  f.is_wheelchair_accessible,
  f.last_verified_at,
  c.name AS city_name,
  s.name AS source_name,
  ratings.average_rating,
  ratings.approved_review_count,
  ratings.admin_review_count,
  latest.review_id AS latest_review_id,
  latest.review_text AS latest_review_text,
  latest.rating AS latest_review_rating,
  latest.author_type AS latest_review_author_type,
  latest.reviewer_name AS latest_review_reviewer_name,
  latest.instagram_url AS latest_review_instagram_url,
  latest.instagram_image_url AS latest_review_instagram_image_url,
  latest.instagram_caption AS latest_review_instagram_caption,
  latest.reviewed_at AS latest_reviewed_at
FROM public.fountains f
LEFT JOIN public.cities c ON c.id = f.city_id
LEFT JOIN public.sources s ON s.id = f.source_id
LEFT JOIN public.fountain_ratings_view ratings ON ratings.fountain_id = f.id
LEFT JOIN public.fountain_latest_review_view latest ON latest.fountain_id = f.id;

-- 4. Re-grant SELECT on views
GRANT SELECT ON public.fountain_ratings_view, public.fountain_latest_review_view, public.fountain_overview_view TO anon, authenticated;
