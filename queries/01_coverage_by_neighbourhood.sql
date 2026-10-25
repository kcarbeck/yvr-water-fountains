-- How much of each neighbourhood have we reviewed, and how good is it?
-- One row per neighbourhood, sorted by number of fountains.
select
  f.neighbourhood,
  count(*)                                         as fountains,
  count(r.average_rating)                          as reviewed,
  round(100.0 * count(r.average_rating) / count(*), 1) as pct_reviewed,
  round(avg(r.average_rating), 1)                  as mean_rating
from fountains f
left join fountain_ratings_view r on r.fountain_id = f.id
group by f.neighbourhood
order by fountains desc;
