-- Do Park Board fountains score differently from Engineering (street) ones?
-- The City's IDs tell us who maintains each fountain:
--   DFPB...  = Vancouver Park Board      DFENG... = Engineering (streets)
--   digits   = City of Burnaby open data (their asset number)
--   no ID    = added by us (not in either city's open data)
-- Descriptive only: too few reviews for a statistical test.
select
  case
    when f.external_id like 'DFPB%'  then 'Park Board'
    when f.external_id like 'DFENG%' then 'Engineering'
    when f.external_id ~ '^[0-9]+$'  then 'Burnaby'
    when f.external_id is null       then 'Added by us'
    else 'Other'
  end                                   as maintainer,
  count(*)                              as fountains,
  count(r.average_rating)               as reviewed,
  round(avg(r.average_rating), 1)       as mean_rating,
  min(r.average_rating)                 as worst,
  max(r.average_rating)                 as best
from fountains f
left join fountain_ratings_view r on r.fountain_id = f.id
group by 1
order by fountains desc;
