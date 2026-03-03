# Instagram Post Linking Tool — Design

**Date:** 2026-03-02
**Status:** Completed

---

## Problem

The @yvrwaterfountains Instagram account has 20-50 posts reviewing water fountains. Only 3 are linked to fountains in the database. The current admin form is too tedious for bulk entry (6 sub-ratings per review). We need an efficient way to backfill historical posts and handle future posts going forward.

## Solution

### Part 1: Backfill Tool (local HTML page)

A standalone page at `docs/link-instagram.html` for bulk-linking exported Instagram posts to fountains.

**Workflow per post:**
1. Load Instagram export JSON via file picker
2. For each post: show caption + photo alongside a map of all fountains
3. Fuzzy-match caption text against fountain names/neighbourhoods, highlight best match
4. Auto-extract rating from caption (regex for X/10 patterns)
5. User confirms or adjusts fountain selection + rating
6. Write to Supabase `reviews` table as `author_type='admin'`, `status='approved'`
7. Track progress ("12 of 35 linked") so you can stop and resume

**Data written per linked post:**

| Field | Value |
|-------|-------|
| fountain_id | Selected fountain UUID |
| author_type | 'admin' |
| status | 'approved' |
| rating | Extracted/confirmed rating (1-10) |
| review_text | Instagram caption |
| instagram_url | Post URL (reconstructed from export) |
| instagram_caption | Caption text |
| visit_date | Post date from export |

**Fuzzy matching:** Token-based scoring — split caption into words, score each fountain by how many caption words appear in its name + neighbourhood. Weight exact park name matches heavily.

**UI layout:** Left side = post card (caption, date, photo). Right side = map with fountains, suggested match highlighted green, search bar. Bottom = rating field, "Confirm & Next" button, skip button.

### Part 2: Future Post Notifications (Graph API)

When the Phase 3 Instagram polling function detects a new post:

1. Post saved to Supabase as draft review (no fountain linked)
2. Auto-matching + rating extraction runs server-side
3. Email notification sent via Resend:
   - Shows caption, suggested fountain match, extracted rating
   - **"Confirm match"** — one-tap from phone, review goes live
   - **"Review manually"** — opens linking page for this post
4. If auto-match is wrong, user picks correct fountain or creates a new one

### Part 3: New Fountain Creation (both flows)

When a post reviews a fountain not in the database:

1. Tap "Add new fountain" button
2. Mini form: name, tap map for coordinates (lat/lng auto-fill)
3. Neighbourhood auto-fills from nearest existing fountain
4. City defaults to Vancouver
5. Inserted into `fountains` table with `source='community submitted'`
6. Post immediately linked to the new fountain

## Known Data Fixes

Apply during setup or as a separate migration:

| Fountain | Issue | Action |
|----------|-------|--------|
| Hillcrest `DFPB0071` "North of playground" | Point not near playground | Update coordinates (confirm position on map) |
| Cambie `DFENG0047` "4963 Cambie St" | Point slightly off, listed as Burnaby | Adjust coordinates, verify city = Vancouver |

## Architecture Decisions

- **Standalone HTML page** (not Netlify function) — fits existing vanilla JS architecture, no deploy needed for backfill, reuses map/marker code from admin form
- **Client-side fuzzy matching** — 428 fountains is trivially small, no server needed
- **Same Supabase auth flow as admin form** — sign in with admin credentials, write reviews directly
- **Resend for notifications** — same service planned for review moderation emails, free tier is plenty
