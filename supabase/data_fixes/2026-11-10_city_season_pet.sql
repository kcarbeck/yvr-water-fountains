-- =====================================================================
-- 2026-11-10  Season and pet-friendly values from the City of Vancouver
-- ---------------------------------------------------------------------
-- The city's open data has IN_OPERATION and PET_FRIENDLY columns, but the
-- original import dropped them, so the Vancouver fountains showed Unknown. This
-- copies them back from data/raw/vancouver_fountains_raw.csv, matched by
-- external_id (the city's MAPID). Values below are the city's text as is.
--
--   IN_OPERATION "spring to fall" or "May-October"
--       -> operational_status 'seasonal', season_note 'about May to October',
--          anti_freeze false (off in winter)
--   IN_OPERATION "Year Round" or "year-round"  -> anti_freeze true
--   PET_FRIENDLY "Y" / "N"                     -> pet_friendly 'yes' / 'no'
--   blank                                      -> left as Unknown
--
-- Only fields that are still unknown are filled: anything we have seen
-- ourselves (a review's answer, the Empire Fields note) is kept.
-- Burnaby's file has no such columns, so Burnaby fountains are untouched.
--
-- Rollback: supabase/rollbacks/rollback_2026-11-10_city_season_pet.sql
-- Safe to run twice: the second run finds nothing left to fill.
-- The whole file is one transaction: if a check fails, nothing changes.
-- =====================================================================

begin;

create temporary table city_values (
  external_id  text primary key,
  in_operation text,      -- the city's IN_OPERATION, as written
  pet_friendly text       -- the city's PET_FRIENDLY: Y, N or blank
) on commit drop;

-- 243 city rows that have at least one of the two values.
-- DFPB0066 is used twice in the city file; the Empire Fields field house
-- row is stored here as DFPB0066-EF (both rows say "spring to fall").
insert into city_values (external_id, in_operation, pet_friendly) values
  ('DFENG0001', 'May-October', 'N'),
  ('DFENG0002', 'May-October', 'N'),
  ('DFENG0003', 'May-October', 'N'),
  ('DFENG0004', 'May-October', 'Y'),
  ('DFENG0005', 'May-October', 'N'),
  ('DFENG0006', 'May-October', 'N'),
  ('DFENG0007', 'May-October', 'N'),
  ('DFENG0008', 'May-October', 'N'),
  ('DFENG0010', 'Year Round', 'Y'),
  ('DFENG0011', 'May-October', 'Y'),
  ('DFENG0012', 'May-October', 'N'),
  ('DFENG0013', 'May-October', 'N'),
  ('DFENG0014', 'May-October', 'N'),
  ('DFENG0015', 'May-October', 'N'),
  ('DFENG0016', 'May-October', 'N'),
  ('DFENG0017', 'May-October', 'N'),
  ('DFENG0018', 'May-October', 'Y'),
  ('DFENG0019', 'Year Round', 'N'),
  ('DFENG0020', 'Year Round', 'N'),
  ('DFENG0021', 'May-October', 'Y'),
  ('DFENG0022', 'May-October', 'N'),
  ('DFENG0023', 'Year Round', 'N'),
  ('DFENG0024', 'Year Round', 'N'),
  ('DFENG0025', 'Year Round', 'N'),
  ('DFENG0026', 'May-October', 'N'),
  ('DFENG0027', 'Year Round', 'N'),
  ('DFENG0028', 'May-October', 'N'),
  ('DFENG0029', 'Year Round', 'N'),
  ('DFENG0030', 'Year Round', 'N'),
  ('DFENG0031', 'Year Round', 'N'),
  ('DFENG0032', 'May-October', 'N'),
  ('DFENG0033', 'May-October', 'N'),
  ('DFENG0034', 'May-October', 'N'),
  ('DFENG0035', 'Year Round', 'N'),
  ('DFENG0036', 'Year Round', 'N'),
  ('DFENG0037', 'Year Round', 'N'),
  ('DFENG0038', 'Year Round', 'N'),
  ('DFENG0039', 'Year Round', 'Y'),
  ('DFENG0040', 'Year Round', 'N'),
  ('DFENG0041', 'May-October', 'N'),
  ('DFENG0042', 'Year Round', 'N'),
  ('DFENG0043', 'Year Round', 'N'),
  ('DFENG0044', 'Year Round', 'N'),
  ('DFENG0045', 'May-October', 'N'),
  ('DFENG0046', 'Year Round', 'N'),
  ('DFENG0047', 'Year Round', 'N'),
  ('DFENG0048', 'Year Round', 'N'),
  ('DFENG0049', 'May-October', 'Y'),
  ('DFENG0050', 'May-October', 'Y'),
  ('DFENG0051', 'Year Round', 'N'),
  ('DFENG0052', 'May-October', 'Y'),
  ('DFENG0053', 'Year Round', 'Y'),
  ('DFENG0054', 'Year Round', 'N'),
  ('DFENG0500', 'Year Round', 'N'),
  ('DFENG0501', 'Year Round', 'N'),
  ('DFENG0502', 'Year Round', 'N'),
  ('DFENG0503', 'Year Round', 'N'),
  ('DFENG0504', 'Year Round', 'N'),
  ('DFENG0505', 'Year Round', 'N'),
  ('DFENG0601', 'May-October', 'N'),
  ('DFENG0602', 'May-October', 'N'),
  ('DFENG0603', 'May-October', 'N'),
  ('DFENG0604', 'May-October', 'N'),
  ('DFENG0605', 'May-October', 'N'),
  ('DFENG0606', 'May-October', 'N'),
  ('DFENG0607', 'May-October', 'N'),
  ('DFENG0608', 'May-October', 'N'),
  ('DFENG0609', 'May-October', 'N'),
  ('DFENG0702', 'May-October', 'N'),
  ('DFENG0703', 'May-October', 'N'),
  ('DFENG0705', 'May-October', 'N'),
  ('DFENG0706', 'May-October', 'N'),
  ('DFENG0707', 'May-October', 'N'),
  ('DFENG0708', 'May-October', 'N'),
  ('DFENG0710', 'May-October', 'N'),
  ('DFENG0711', 'May-October', 'N'),
  ('DFENG0801', 'May-October', 'N'),
  ('DFENG0802', 'May-October', 'N'),
  ('DFENG0803', 'May-October', 'N'),
  ('DFENG0804', 'May-October', 'N'),
  ('DFENG0805', 'May-October', 'N'),
  ('DFENG0806', 'May-October', 'N'),
  ('DFENG0807', 'May-October', 'N'),
  ('DFENG0808', 'May-October', 'N'),
  ('DFENG0809', 'May-October', 'N'),
  ('DFENG0810', 'May-October', 'N'),
  ('DFENG0811', 'May-October', 'N'),
  ('DFPB0001', 'spring to fall', null),
  ('DFPB0002', 'spring to fall', null),
  ('DFPB0003', 'spring to fall', null),
  ('DFPB0004', 'spring to fall', null),
  ('DFPB0005', 'spring to fall', null),
  ('DFPB0006', 'spring to fall', null),
  ('DFPB0007', 'spring to fall', null),
  ('DFPB0008', 'spring to fall', null),
  ('DFPB0009', 'spring to fall', null),
  ('DFPB0010', 'spring to fall', null),
  ('DFPB0011', 'spring to fall', null),
  ('DFPB0012', 'spring to fall', null),
  ('DFPB0013', 'spring to fall', null),
  ('DFPB0014', 'spring to fall', null),
  ('DFPB0016', 'spring to fall', null),
  ('DFPB0017', 'spring to fall', null),
  ('DFPB0018', 'spring to fall', null),
  ('DFPB0019', 'spring to fall', null),
  ('DFPB0021', 'spring to fall', null),
  ('DFPB0022', 'spring to fall', null),
  ('DFPB0023', 'spring to fall', null),
  ('DFPB0024', 'spring to fall', null),
  ('DFPB0025', 'spring to fall', null),
  ('DFPB0027', 'year-round', null),
  ('DFPB0029', 'spring to fall', null),
  ('DFPB0032', 'spring to fall', null),
  ('DFPB0033', 'spring to fall', null),
  ('DFPB0034', 'year-round', null),
  ('DFPB0035', 'spring to fall', null),
  ('DFPB0036', 'spring to fall', null),
  ('DFPB0037', 'spring to fall', null),
  ('DFPB0038', 'spring to fall', null),
  ('DFPB0041', 'spring to fall', null),
  ('DFPB0042', 'year-round', null),
  ('DFPB0043', 'spring to fall', null),
  ('DFPB0044', 'spring to fall', null),
  ('DFPB0045', 'spring to fall', null),
  ('DFPB0046', 'spring to fall', null),
  ('DFPB0047', 'spring to fall', null),
  ('DFPB0048', 'spring to fall', null),
  ('DFPB0049', 'spring to fall', null),
  ('DFPB0050', 'spring to fall', null),
  ('DFPB0051', 'spring to fall', null),
  ('DFPB0052', 'spring to fall', null),
  ('DFPB0053', 'spring to fall', null),
  ('DFPB0054', 'spring to fall', null),
  ('DFPB0055', 'spring to fall', null),
  ('DFPB0056', 'spring to fall', null),
  ('DFPB0058', 'spring to fall', null),
  ('DFPB0059', 'spring to fall', null),
  ('DFPB0060', 'spring to fall', null),
  ('DFPB0061', 'spring to fall', null),
  ('DFPB0062', 'spring to fall', null),
  ('DFPB0063', 'spring to fall', null),
  ('DFPB0064', 'spring to fall', null),
  ('DFPB0065', 'spring to fall', null),
  ('DFPB0066', 'spring to fall', null),
  ('DFPB0066-EF', 'spring to fall', null),
  ('DFPB0067', 'spring to fall', null),
  ('DFPB0074', 'spring to fall', null),
  ('DFPB0075', 'spring to fall', null),
  ('DFPB0076', 'spring to fall', null),
  ('DFPB0077', 'spring to fall', null),
  ('DFPB0078', 'spring to fall', null),
  ('DFPB0079', 'spring to fall', null),
  ('DFPB0080', 'spring to fall', null),
  ('DFPB0081', 'spring to fall', null),
  ('DFPB0082', 'spring to fall', null),
  ('DFPB0083', 'spring to fall', null),
  ('DFPB0084', 'spring to fall', null),
  ('DFPB0085', 'spring to fall', null),
  ('DFPB0086', 'spring to fall', null),
  ('DFPB0087', 'spring to fall', null),
  ('DFPB0088', 'spring to fall', null),
  ('DFPB0089', 'spring to fall', null),
  ('DFPB0090', 'spring to fall', null),
  ('DFPB0093', 'spring to fall', null),
  ('DFPB0094', 'spring to fall', null),
  ('DFPB0095', 'spring to fall', null),
  ('DFPB0096', 'spring to fall', null),
  ('DFPB0097', 'spring to fall', null),
  ('DFPB0098', 'spring to fall', null),
  ('DFPB0099', 'spring to fall', null),
  ('DFPB0100', 'spring to fall', null),
  ('DFPB0101', 'spring to fall', null),
  ('DFPB0103', 'year-round', null),
  ('DFPB0104', 'spring to fall', null),
  ('DFPB0105', 'spring to fall', null),
  ('DFPB0107', 'spring to fall', null),
  ('DFPB0108', 'spring to fall', null),
  ('DFPB0109', 'spring to fall', null),
  ('DFPB0110', 'spring to fall', null),
  ('DFPB0111', 'spring to fall', null),
  ('DFPB0112', 'spring to fall', null),
  ('DFPB0113', 'spring to fall', null),
  ('DFPB0114', 'spring to fall', null),
  ('DFPB0115', 'spring to fall', null),
  ('DFPB0116', 'spring to fall', null),
  ('DFPB0117', 'spring to fall', null),
  ('DFPB0118', 'spring to fall', null),
  ('DFPB0120', 'spring to fall', null),
  ('DFPB0123', 'year-round', null),
  ('DFPB0124', 'spring to fall', null),
  ('DFPB0125', 'spring to fall', null),
  ('DFPB0126', 'spring to fall', null),
  ('DFPB0127', 'spring to fall', null),
  ('DFPB0128', 'spring to fall', null),
  ('DFPB0129', 'spring to fall', null),
  ('DFPB0130', 'spring to fall', null),
  ('DFPB0131', 'spring to fall', null),
  ('DFPB0132', 'spring to fall', null),
  ('DFPB0133', 'spring to fall', null),
  ('DFPB0134', 'spring to fall', null),
  ('DFPB0135', 'spring to fall', null),
  ('DFPB0136', 'spring to fall', null),
  ('DFPB0137', 'spring to fall', null),
  ('DFPB0138', 'spring to fall', null),
  ('DFPB0139', 'spring to fall', null),
  ('DFPB0140', 'spring to fall', null),
  ('DFPB0141', 'spring to fall', null),
  ('DFPB0142', 'year-round', null),
  ('DFPB0143', 'year-round', null),
  ('DFPB0145', 'spring to fall', null),
  ('DFPB0146', 'spring to fall', null),
  ('DFPB0147', 'spring to fall', null),
  ('DFPB0151', 'year-round', null),
  ('DFPB0152', 'spring to fall', null),
  ('DFPB0153', 'spring to fall', null),
  ('DFPB0155', 'spring to fall', null),
  ('DFPB0156', 'spring to fall', null),
  ('DFPB0158', 'spring to fall', null),
  ('DFPB0160', 'spring to fall', null),
  ('DFPB0161', 'spring to fall', null),
  ('DFPB0162', 'year-round', null),
  ('DFPB0163', 'spring to fall', null),
  ('DFPB0164', 'spring to fall', null),
  ('DFPB0165', 'spring to fall', null),
  ('DFPB0167', 'spring to fall', null),
  ('DFPB0168', 'spring to fall', null),
  ('DFPB0169', 'spring to fall', null),
  ('DFPB0170', 'spring to fall', null),
  ('DFPB0171', 'spring to fall', null),
  ('DFPB0172', 'spring to fall', null),
  ('DFPB0173', 'spring to fall', null),
  ('DFPB0174', 'spring to fall', null),
  ('DFPB0175', 'spring to fall', null),
  ('DFPB0176', 'year-round', null),
  ('DFPB0177', 'spring to fall', null),
  ('DFPB0178', 'spring to fall', null),
  ('DFPB0179', 'spring to fall', null),
  ('DFPB0180', 'spring to fall', null),
  ('DFPB0181', 'spring to fall', null),
  ('DFPB0182', 'spring to fall', null),
  ('DFPB0183', 'spring to fall', null),
  ('DFPB0184', 'spring to fall', null),
  ('DFPB0185', 'spring to fall', null);

-- Check: every row matches exactly one fountain from the Vancouver data.
do $$
declare
  n_missing int;
begin
  select count(*) into n_missing
  from city_values v
  where (select count(*) from public.fountains f
         join public.sources s on s.id = f.source_id
         where f.external_id = v.external_id and s.name = 'Vancouver Open Data') <> 1;
  if n_missing > 0 then
    raise exception 'city_season_pet: % rows do not match exactly one fountain', n_missing;
  end if;
  -- and every value is one this file knows how to read
  if exists (select 1 from city_values
             where coalesce(lower(in_operation), '') not in ('', 'spring to fall', 'may-october', 'year round', 'year-round')
                or coalesce(pet_friendly, '') not in ('', 'Y', 'N')) then
    raise exception 'city_season_pet: unexpected IN_OPERATION or PET_FRIENDLY text';
  end if;
end $$;

-- Seasonal: status, note and "off in winter", each only where unknown.
update public.fountains f
set operational_status = case when f.operational_status = 'unknown' then 'seasonal' else f.operational_status end,
    season_note        = coalesce(f.season_note, 'about May to October'),
    anti_freeze        = coalesce(f.anti_freeze, false)
from city_values v
where v.external_id = f.external_id
  and lower(v.in_operation) in ('spring to fall', 'may-october')
  and f.operational_status in ('unknown', 'seasonal')   -- never on a closed fountain
  and (f.operational_status = 'unknown' or f.season_note is null or f.anti_freeze is null);

-- Year-round: anti-freeze on, only where unknown.
update public.fountains f
set anti_freeze = true
from city_values v
where v.external_id = f.external_id
  and lower(v.in_operation) in ('year round', 'year-round')
  and f.anti_freeze is null;

-- Pet friendly.
update public.fountains f
set pet_friendly = case v.pet_friendly when 'Y' then 'yes' when 'N' then 'no' end
from city_values v
where v.external_id = f.external_id
  and v.pet_friendly in ('Y', 'N')
  and f.pet_friendly = 'unknown';

-- Summary: what the map will show for the Vancouver fountains.
select case when f.anti_freeze then 'Year-round'
            when f.anti_freeze = false or f.operational_status = 'seasonal' then 'Seasonal'
            else 'Unknown' end as season,
       f.pet_friendly,
       count(*) as fountains
from public.fountains f
join public.sources s on s.id = f.source_id
where s.name = 'Vancouver Open Data'
group by 1, 2
order by 1, 2;

commit;
