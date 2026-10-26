-- =====================================================================
-- 2026-10-20  Repair garbled emoji in 4 review captions
-- ---------------------------------------------------------------------
-- Four captions were imported with the wrong text encoding, so emoji show
-- on the map as mojibake ("ð¤¢"). The bytes are intact, only decoded
-- as Latin-1; converting them back gives the original text exactly.
--
-- Rollback: supabase/rollbacks/rollback_2026-10-20_repair_garbled_emoji.sql
-- =====================================================================
begin;

update public.reviews
set review_text       = convert_from(convert_to(review_text, 'LATIN1'), 'UTF8'),
    instagram_caption = convert_from(convert_to(instagram_caption, 'LATIN1'), 'UTF8')
where id in ('034dcea2-e6c0-4ab6-a0b0-e8e9e32bc82a',   -- New Brighton park
             '88287976-57d4-4ac9-9341-c71c1f4f6822',   -- Rupert Park
             'bbc801c4-63ec-4a47-9174-b102d567dd74',   -- Second beach pool
             'd7277c31-5d6a-47d8-bf20-891984363892')   -- Trout lake
  and review_text ~ '[\u0080-ÿ]';                 -- only if still garbled

-- check: should list the 4 captions with real emoji
select id, left(review_text, 70) as start from public.reviews
where id in ('034dcea2-e6c0-4ab6-a0b0-e8e9e32bc82a', '88287976-57d4-4ac9-9341-c71c1f4f6822',
             'bbc801c4-63ec-4a47-9174-b102d567dd74', 'd7277c31-5d6a-47d8-bf20-891984363892');

commit;
