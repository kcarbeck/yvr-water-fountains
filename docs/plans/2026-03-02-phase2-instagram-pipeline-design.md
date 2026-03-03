# Phase 2: Instagram → Map Pipeline — Design Doc

**Goal:** Make it dead simple to add Instagram reviews to the map: paste a URL + caption, confirm the fountain match, done. Also backfill the 42 existing reviews with their missing Instagram URLs, and set up a weekly email reminder so new posts don't slip through the cracks.

**Architecture:** No external APIs required. The admin review form is enhanced with auto-extraction (rating from caption, fuzzy fountain matching). A backfill tool helps paste URLs for existing reviews. A weekly Resend email nudges you to check for new posts. Everything runs on the existing stack — Supabase, Netlify, vanilla JS.

**Tech Stack:** Vanilla JS (browser), Netlify Functions (Node.js 18), Resend (email), Supabase (Postgres)

---

## Prerequisites (manual, one-time)

| Step | What | Time |
|------|------|------|
| 1 | Sign up for Resend at resend.com, get API key | ~5 min |
| 2 | Add environment variables to Netlify (see below) | ~5 min |

No Facebook, no Instagram API, no Meta developer account needed.

### Netlify Environment Variables

| Variable | Description |
|----------|-------------|
| `RESEND_API_KEY` | Resend email service API key |
| `SUPABASE_URL` | Supabase project URL (already set if Netlify functions were used before) |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key (server-side only, bypasses RLS) |
| `ADMIN_EMAIL` | Email address to receive reminders (yvrwaterfountains@gmail.com) |

---

## Component 1: Polished Admin Review Form

The existing admin review form (`docs/admin_review_form.html` + `docs/js/admin-review-form.js`) already works. Enhancements:

### New workflow (paste-and-confirm)

1. Admin pastes an Instagram post URL into the URL field
2. Admin pastes the caption into the caption field
3. **System auto-extracts** the rating from the caption (e.g., "7.5/10" → 7.5)
4. **System auto-matches** the fountain from caption text using fuzzy matching
5. Map zooms to the matched fountain, highlights it
6. Admin confirms or picks a different fountain
7. One click to submit — review is approved and live on the map

### What changes in the code

- **Auto-extract rating**: When caption text changes, run `extractRating()` (already exists in `link-instagram.js`) and pre-fill the rating field
- **Auto-match fountain**: When caption text changes, run `fuzzyMatchFountains()` (already exists in `link-instagram.js`) against loaded fountain data, auto-select the best match on the map
- The existing form fields (Instagram URL, caption, rating, visit date, notes) stay the same — we just auto-fill more of them

---

## Component 2: Backfill Tool

A simple admin page that lists the 42 reviews with missing `instagram_url`, shows each review's caption, and provides an input field to paste the matching Instagram post URL.

### Page: `docs/backfill-instagram.html`

- Admin signs in (same Supabase auth as other admin pages)
- Page loads all reviews where `instagram_url IS NULL` and `author_type = 'admin'`
- Each review displayed as a card: caption text, rating, visit date, fountain name
- Each card has an input field for pasting the Instagram URL
- "Save" button updates `instagram_url` in Supabase
- Progress counter: "12 of 42 updated"

This is a one-time tool. Once all 42 URLs are filled in, the page shows "All done!"

---

## Component 3: Weekly Reminder Email

A Netlify Scheduled Function sends a weekly email: "Have you posted any new reels this week? Add them to the map!"

### Function: `netlify/functions/weekly-reminder.js`

**Schedule:** Mondays at 10am Pacific (6pm UTC) — `0 18 * * 1`

**Email content:**
```
Subject: Weekly reminder — any new fountain reviews?

Hey! Quick check: have you or your friend posted any new
@yvrwaterfountains reels this week?

If so, add them to the map:
[Open Admin Form] → paste URL + caption, confirm fountain, done!

Currently on the map: [X] reviewed fountains out of [Y] total.

— YVR Water Fountains Bot
```

The function queries Supabase for the current review/fountain counts to include in the email.

---

## What's NOT in this phase

- Instagram Graph API / auto-detection (requires Facebook)
- Public review form / community submissions
- Auto-screening / profanity filter / spam detection
- "Request a review" and "Suggest a fountain" forms
- Moderation dashboard redesign

---

## Security Notes

- `SUPABASE_SERVICE_ROLE_KEY` is only used server-side in Netlify Functions, never exposed to the browser.
- Admin pages use Supabase auth (email + password) — same as current setup.
- The weekly reminder function uses the service role key to query counts.
