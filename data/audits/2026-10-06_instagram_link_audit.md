# Instagram ↔ fountain link audit — 2026-10-06

**What was checked:** all 42 approved @yvrwaterfountains reviews. For each one I compared
(1) the Instagram caption, (2) the cover frame of the reel (from Instagram's public embed),
(3) the linked fountain's name, and (4) the City's *detailed* location text and nearby
fountains (PostGIS, within 250 m).

**Limits:** I could see each reel's cover frame, not the full video (Instagram needs a login
to play reels). A cover frame shows the fountain style and surroundings, but it can't prove
which of two fountains 50 m apart you filmed. Those cases are marked *uncertain*.

## Summary

| Result | Reviews |
|---|---|
| Correct fountain — caption, image and City description agree | 33 |
| **Wrong fountain** — fixed in `supabase/data_fixes/2026-10-06_review_link_fixes.sql` | 3 |
| **Wrong fountain** — needs your decision (section B of that file) | 2 |
| Wrong or missing Instagram link (Hinge Park; False Creek CC) | 2 (both also counted above) |
| Uncertain — can't tell from one frame (Empire Fields cluster, Hillcrest) | 4 |
| Fountains you reviewed that **aren't in the City's open data** | 9 |

## Wrong links

| Caption says | Was linked to | Fix |
|---|---|---|
| "Empire fields, south side by the basketball courts and parking lot" | David Lam Park (Downtown) | → DFPB0068 *Empire Fields – East of basketball courts* (A1) |
| "Last of empire fields … by the bathrooms" (video: fountain on field-house wall, 1954 Miracle Mile plaque) | DFPB0070 *soccer fields* | → re-added City fountain *field house at Empire Field* (A2, see data issue 1) |
| "False Creek Community Centre!" (indoors, Granville Island) | Douglas Park community centre, ~2 km away | → new *False Creek Community Centre (indoor)* (A4) |
| "BTS waterfountain … #theorpheumtheatre" (backstage, not public) | 4th & Arbutus street fountain | your call: own non-public fountain, or hide (B1) |
| "Kensington Park! … inside the community centre" | the *outdoor* Kensington Park fountain | your call: separate indoor record (B2) |

## Wrong / missing Instagram links

- **Hinge Park** review uses the **Charleson Park** post's link (both say DKQkvZWv4AT). Link cleared (A3); paste the right one in B4.
- **False Creek Community Centre** review has no link at all (B4).

## Uncertain (need your memory)

- **Empire Fields** — five reviews, and the City lists the fountains with near-identical
  coordinates (DFPB0068 and DFPB0070 are at the *exact same point*). Current links:
  "near the statues" → DFPB0067 *north of empire field*; "again… useless" → DFPB0069
  *east of playgrounds*; "between the fields" → a fountain we created 72 m from DFPB0070,
  which may be the same one (B3). Best fix is to drop real pins next time you're there.
- **Hillcrest playground** → DFPB0071 *north of playground*: the cover frame shows a
  ball-diamond backstop rather than a playground.

## Not in the City's open data (genuine additions)

Vancouver Public Library 8th floor · YVR domestic C51 · Rainbow Park (Richards & Smithe) ·
East Hastings & Commercial · Adanac & Garden · Templeton track · Wall St & Renfrew ·
False Creek CC (indoor) · Empire Fields field house (in the City file, but under a
duplicated ID — see below). Nothing in either city's data lies within 250 m of the first seven.

## Problems found in the source data (worth reporting to the City)

1. **Duplicate ID.** `DFPB0066` is used for two different fountains (Sunset Beach *and*
   the Empire Fields field house). Our import's unique-ID rule silently dropped one.
2. **Placeholder coordinates.** Six different Stanley Park fountains (Admin building,
   Brockton Cricket Pavilion, Brockton Point lighthouse, Lawn Bowling, dog off-leash area,
   SW of playground) all share one point near Prospect Point, kilometres from some of them.
   DFPB0068/DFPB0070 at Empire Fields share one point too.
3. **Burnaby labelled as Vancouver.** All 151 Burnaby fountains had city "Vancouver" and
   source "Vancouver Open Data" in our database (fixed in A5).

## Other small things

- The caption rating "-10/10" (Empire Fields, between the fields) is stored as 0 because
  ratings must be 0–10. Fine, just a heads-up.
- The live map showed every fountain as "Pet friendly: No" because the code treated the
  word "unknown" as containing "no". Fixed in `docs/js/fountain-data.js`.
