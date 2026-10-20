-- =====================================================================
-- ROLLBACK for supabase/data_fixes/2026-10-20_repair_garbled_emoji.sql
-- Turns the 4 repaired captions back into their garbled form (the exact
-- reverse conversion) and restores their original updated_at.
-- =====================================================================
begin;

alter table public.reviews disable trigger reviews_touch_updated_at;

update public.reviews r
set review_text       = convert_from(convert_to(r.review_text, 'UTF8'), 'LATIN1'),
    instagram_caption = convert_from(convert_to(r.instagram_caption, 'UTF8'), 'LATIN1'),
    updated_at        = v.updated_at::timestamptz
from (values
  ('034dcea2-e6c0-4ab6-a0b0-e8e9e32bc82a', '2026-03-03T06:14:52.289761+00:00'),
  ('88287976-57d4-4ac9-9341-c71c1f4f6822', '2026-03-03T06:15:13.047323+00:00'),
  ('bbc801c4-63ec-4a47-9174-b102d567dd74', '2026-03-03T06:10:48.18744+00:00'),
  ('d7277c31-5d6a-47d8-bf20-891984363892', '2026-03-03T06:10:18.673794+00:00')
) as v(id, updated_at)
where r.id = v.id::uuid
  and r.review_text !~ '[\u0080-ÿ]';     -- only if currently repaired

alter table public.reviews enable trigger reviews_touch_updated_at;

commit;
