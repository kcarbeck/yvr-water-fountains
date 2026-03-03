# Phase 2: Instagram → Map Pipeline — Design Doc

**Goal:** When a new Instagram reel is posted on @yvrwaterfountains, the system detects it daily, extracts the rating, matches it to a fountain, and emails you a one-tap confirm link. You tap confirm on your phone and it's live on the map. A separate one-time backfill fixes the 42 existing reviews that are missing Instagram URLs and photos.

**Architecture:** Netlify Scheduled Function polls Instagram Graph API once daily. New posts become pending admin reviews. Resend sends email notifications with signed approve/reject links handled by a second Netlify Function. Supabase remains the database. No changes to the frontend map — it already reads from Supabase.

**Tech Stack:** Netlify Scheduled Functions, Instagram Graph API, Resend (email), Supabase (Postgres + service role key), JWT for signed email links.

---

## Prerequisites (manual, one-time)

| Step | What | Time |
|------|------|------|
| 1 | Switch @yvrwaterfountains to Business or Creator account (free, in Instagram settings) | ~2 min |
| 2 | Register a Meta Developer App, add Instagram Graph API product, generate a long-lived access token | ~30 min |
| 3 | Sign up for Resend at resend.com, get API key | ~5 min |
| 4 | Add environment variables to Netlify (see below) | ~5 min |

### Netlify Environment Variables

| Variable | Description |
|----------|-------------|
| `INSTAGRAM_ACCESS_TOKEN` | Long-lived Instagram Graph API token (60-day expiry, auto-refreshed) |
| `INSTAGRAM_USER_ID` | Your Instagram Business account numeric ID |
| `RESEND_API_KEY` | Resend email service API key |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (server-side only, bypasses RLS) |
| `REVIEW_ACTION_SECRET` | Random secret string for signing email action links (JWT) |
| `ADMIN_EMAIL` | Email address to receive notifications (yvrwaterfountains@gmail.com) |

---

## Database Changes

Two new columns on the existing `reviews` table:

```sql
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS instagram_media_id text;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS flag_reason text;
```

- `instagram_media_id` — Instagram's unique media ID for each post. Used to dedup: the daily poll skips posts whose media ID already exists in the reviews table.
- `flag_reason` — Why a review was held for manual review (e.g., "no fountain match found", "no rating in caption"). Nullable; null means no issues.

No new tables needed.

---

## Netlify Functions

### 1. `poll-instagram.js` (Scheduled — daily)

**Trigger:** Netlify Scheduled Function, cron `0 16 * * *` (8am Pacific / 4pm UTC).

**Flow:**

1. Check token health: if the access token expires within 7 days, auto-refresh it via `GET /oauth/access_token?grant_type=ig_refresh_token&access_token={token}`. If refresh fails, send a warning email and stop.
2. Call `GET /{user-id}/media?fields=id,caption,media_url,permalink,timestamp&limit=10` to fetch recent posts.
3. Query Supabase for existing `instagram_media_id` values to find which posts are already in the DB.
4. For each new (unseen) post:
   a. **Extract rating** from caption using regex: `(\d+\.?\d*)\s*/\s*10`. If no match, flag as "no rating in caption".
   b. **Fuzzy-match fountain** by searching caption text against fountain names in the `fountains` table. Use simple substring/word matching (same approach as Phase 0.5 backfill tool). If no match, flag as "no fountain match found".
   c. **Insert review** into Supabase:
      - `fountain_id`: matched fountain's UUID (or null if no match)
      - `author_type`: `'admin'`
      - `status`: `'pending'`
      - `rating`: extracted rating (or null)
      - `instagram_url`: post permalink
      - `instagram_image_url`: post media_url
      - `instagram_caption`: post caption
      - `instagram_media_id`: post media ID
      - `reviewer_name`: `'yvrwaterfountains'`
      - `visit_date`: post timestamp date
      - `flag_reason`: null if clean, or reason string if flagged
   d. **Send email** via Resend (see Email Format below).
5. Log summary: "Processed X new posts, Y matched, Z flagged."

### 2. `confirm-review.js` (HTTP endpoint)

**Trigger:** GET request from email link.

**URL format:** `/.netlify/functions/confirm-review?token={jwt}&action={approve|reject|dashboard}`

**Flow:**

1. Decode and verify the JWT token using `REVIEW_ACTION_SECRET`. Token payload contains `reviewId` and `exp` (48-hour expiry).
2. If `action=approve`: update review `status = 'approved'`, `reviewed_at = now()`. Return a simple HTML page: "Review approved! It's now live on the map."
3. If `action=reject`: update review `status = 'rejected'`. Return: "Review rejected."
4. If `action=dashboard`: redirect to the moderation dashboard URL.
5. If token is expired or invalid: return "This link has expired. Please use the moderation dashboard."

---

## Email Format

### New post detected (good match)

```
Subject: New IG post → [Fountain Name] — [rating]/10

New Instagram post detected
━━━━━━━━━━━━━━━━━━━━━━━━━

Fountain: [Fountain Name] ([external_id])
Rating: [X]/10
Caption: "[First 150 chars of caption...]"
Posted: [date]

[ Confirm & Publish ]  [ Review Manually ]
```

### New post detected (needs attention)

```
Subject: New IG post needs review — [flag reason]

New Instagram post needs your attention
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue: [flag_reason — e.g., "no fountain match found"]
Caption: "[First 150 chars...]"
Posted: [date]

[ Open Dashboard ]
```

### Token expiry warning

```
Subject: Instagram token expires in [N] days

Your Instagram access token expires on [date].
Refresh it at: [Meta developer dashboard URL]
```

---

## One-Time Backfill (separate from daily polling)

A standalone script or single-use Netlify function that runs once to fix the 42 existing reviews:

1. Fetch all posts from the Graph API (paginated — `?limit=50` with cursor pagination until all posts are retrieved).
2. For each post, match to an existing review by comparing caption text (same fuzzy logic as Phase 0.5).
3. Update matched reviews with: `instagram_url` (permalink), `instagram_image_url` (media_url), `instagram_media_id` (media ID).
4. Log results: "Updated X of 42 reviews. Y unmatched."

This runs once and is done. The daily polling handles all new posts going forward.

---

## Admin Form Polish (minor)

The existing admin review form (`admin-review-form.js`) already works. Minor improvements:

- When an Instagram URL is pasted, show an image preview using the Meta oEmbed API (`GET https://graph.facebook.com/v18.0/instagram_oembed?url={url}&access_token={token}`).
- Pre-fill the caption field if the IG URL is recognized from a pending review created by the daily poll.

---

## What's NOT in this phase

- Public review form / community submissions
- Auto-screening / profanity filter / spam detection
- "Request a review" form
- "Suggest a fountain" form
- Moderation dashboard redesign (existing dashboard still works for edge cases)

These are deferred to a future phase focused on community features.

---

## Security Notes

- `SUPABASE_SERVICE_ROLE_KEY` is only used server-side in Netlify Functions, never exposed to the browser.
- Email action links use JWT tokens signed with `REVIEW_ACTION_SECRET`, expiring after 48 hours.
- Instagram access token is stored in Netlify env vars, never in client code.
- The daily function uses the service role key to bypass RLS for inserting admin reviews and updating instagram fields.
