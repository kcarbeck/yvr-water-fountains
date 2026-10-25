-- Data-quality checks on reviews. Each block should ideally return 0 rows.

-- (a) The same Instagram post linked to more than one review
select instagram_url, count(*) as n_reviews, string_agg(f.name, ' | ') as fountains
from reviews r
join fountains f on f.id = r.fountain_id
where instagram_url is not null
group by instagram_url
having count(*) > 1;

-- (b) Approved Instagram reviews with no link to the post
select r.id, f.name, left(r.review_text, 60) as caption_start
from reviews r
join fountains f on f.id = r.fountain_id
where r.author_type = 'admin' and r.status = 'approved' and r.instagram_url is null;

-- (c) The "X/10" in the caption doesn't match the stored rating
select f.name, r.rating as stored,
       substring(coalesce(r.instagram_caption, r.review_text) from '(-?\d+(?:\.\d+)?)\s*/\s*10') as in_caption
from reviews r
join fountains f on f.id = r.fountain_id
where substring(coalesce(r.instagram_caption, r.review_text) from '(-?\d+(?:\.\d+)?)\s*/\s*10')::numeric
      is distinct from r.rating;

-- (d) No word from the fountain's name (4+ letters) appears in the caption —
--     a cheap flag for "linked to the wrong fountain". Expect a few false alarms.
select f.name, left(coalesce(r.instagram_caption, r.review_text), 80) as caption_start
from reviews r
join fountains f on f.id = r.fountain_id
where r.author_type = 'admin'
  and not exists (
    select 1
    from regexp_split_to_table(lower(f.name), '[^a-z]+') as word
    where length(word) >= 4
      and word not in ('park', 'east', 'west', 'north', 'south', 'side')
      and lower(coalesce(r.instagram_caption, r.review_text)) like '%' || word || '%'
  );
