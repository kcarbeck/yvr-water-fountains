-- defines public facing views for aggregate fountain data

create or replace view public.approved_reviews as
select *
from public.reviews
where status = 'approved';

create or replace view public.fountain_review_stats as
select
  r.fountain_id,
  round(avg(r.rating)::numeric, 2) as avg_rating,
  count(r.*) as reviews_count,
  count(r.*) filter (where r.reviewer_type = 'admin') as admin_reviews_count
from public.approved_reviews r
group by r.fountain_id;

create or replace view public.fountain_latest_review as
select
  f.id as fountain_id,
  r.id as review_id,
  r.rating,
  r.title,
  r.body,
  r.reviewer_type,
  r.reviewer_name,
  r.created_at,
  coalesce(r.created_at, now()) as reviewed_at,
  r.instagram_url,
  r.instagram_image_url,
  r.instagram_caption
from public.fountains f
left join lateral (
  select *
  from public.approved_reviews r
  where r.fountain_id = f.id
  order by r.created_at desc
  limit 1
) r on true;

create or replace view public.fountains_public as
select
  f.id,
  f.city_id,
  f.source_id,
  f.name,
  f.neighbourhood,
  f.location_description,
  f.latitude,
  f.longitude,
  f.operational,
  f.operational_season,
  f.pet_friendly,
  f.has_bottle_filler,
  f.is_wheelchair_accessible,
  f.last_verified_at,
  f.external_id,
  f.is_active,
  f.created_at,
  f.updated_at,
  stats.avg_rating as average_rating,
  stats.reviews_count as approved_review_count,
  stats.admin_reviews_count as admin_review_count,
  latest.review_id as latest_review_id,
  latest.rating as latest_review_rating,
  latest.body as latest_review_text,
  latest.reviewer_type as latest_review_author_type,
  latest.reviewer_name as latest_review_reviewer_name,
  latest.instagram_url as latest_review_instagram_url,
  latest.instagram_image_url as latest_review_instagram_image_url,
  latest.instagram_caption as latest_review_instagram_caption,
  latest.reviewed_at as latest_reviewed_at,
  c.name as city_name,
  s.name as source_name,
  case
    when f.pet_friendly = 'y' then 'yes'
    when f.pet_friendly = 'n' then 'no'
    else 'unknown'
  end as pet_friendly_label,
  f.operational as operational_status,
  f.operational_season as season_note
from public.fountains f
left join public.cities c on c.id = f.city_id
left join public.sources s on s.id = f.source_id
left join public.fountain_review_stats stats on stats.fountain_id = f.id
left join public.fountain_latest_review latest on latest.fountain_id = f.id;

-- compatibility view for existing frontend usage
create or replace view public.fountain_overview_view as
select *
from public.fountains_public;
