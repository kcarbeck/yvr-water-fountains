# Phase 2: Instagram → Map Pipeline — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Auto-detect new Instagram posts daily, email a one-tap confirm link, and publish reviews to the map — plus backfill the 42 existing reviews with their missing Instagram URLs and photos.

**Architecture:** Netlify Scheduled Function polls Instagram Graph API daily. New posts become pending admin reviews in Supabase. Resend sends email notifications with JWT-signed approve/reject links, handled by a second Netlify Function. A one-time backfill script fixes existing reviews. No frontend framework — vanilla JS, IIFE modules.

**Tech Stack:** Node.js 18+ (Netlify Functions), Instagram Graph API, Resend (email), Supabase (Postgres via service role key), jsonwebtoken (JWT for signed links), esbuild (Netlify bundler)

**Design doc:** `docs/plans/2026-03-02-phase2-instagram-pipeline-design.md`

---

## Context for the implementer

### Project structure

All served files live under `docs/` (Netlify publish dir). Netlify functions live in `netlify/functions/`. The functions have their own `package.json` at `netlify/functions/package.json`. The root `package.json` is for dev tooling. esbuild bundles functions automatically (configured in `netlify.toml`).

### Key existing files you'll reference

- `netlify/functions/package.json` — functions dependencies (currently only `@supabase/supabase-js`)
- `netlify/functions/submit-review.js` — **BROKEN**, references old table `ratings` and old columns. Will be deleted.
- `netlify/functions/manage-rating.js` — **BROKEN**, same issue. Will be deleted.
- `netlify/functions/trigger-deployment.js` — auto-deployment trigger (still works but not needed; we read live from Supabase now)
- `netlify.toml` — build config, function config, headers, redirects
- `docs/js/link-instagram.js` — contains `extractRating()` (line 268-296) and `fuzzyMatchFountains()` (line 228-266) that we'll port to Node.js
- `docs/js/api.js` — Supabase client helpers (browser-side, not used by functions)
- `supabase/migrations/20241015120000_core_schema.sql` — original DB schema

### Supabase credentials

Functions use `SUPABASE_SERVICE_ROLE_KEY` (env var, bypasses RLS) — NOT the anon key. The anon key in `docs/config.js` is for browser-side reads only.

### Current reviews table columns (after Phase 1)

`id, fountain_id, author_type, status, rating, review_text, reviewer_name, reviewer_email, instagram_url, instagram_image_url, instagram_caption, visit_date, reviewed_at, approved_by, created_at, updated_at`

Status values: `pending`, `approved`, `rejected`

---

## Task 1: Database migration — add instagram_media_id and flag_reason columns

**Files:**
- Create: `supabase/migrations/20260302_add_instagram_media_id.sql`

**Step 1: Write the migration SQL**

Create file `supabase/migrations/20260302_add_instagram_media_id.sql`:

```sql
-- Phase 2: Add columns for Instagram Graph API integration
-- instagram_media_id: dedup key for daily polling (Instagram's unique media ID per post)
-- flag_reason: why a review was held for manual review (null = no issues)

ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS instagram_media_id text;
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS flag_reason text;

-- Index for fast dedup lookups during daily polling
CREATE INDEX IF NOT EXISTS idx_reviews_instagram_media_id
  ON public.reviews(instagram_media_id)
  WHERE instagram_media_id IS NOT NULL;
```

**Step 2: Apply the migration to Supabase**

Run this SQL in the Supabase SQL Editor (Dashboard → SQL Editor → New Query → paste → Run). Alternatively, use curl:

```bash
curl -X POST "https://hnyktzfyquvmpthfwpvd.supabase.co/rest/v1/rpc" \
  -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  --data-raw '...'
```

Since we can't run raw DDL via REST, use the Supabase Dashboard SQL Editor. Verify by running:

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'reviews' AND column_name IN ('instagram_media_id', 'flag_reason');
```

Expected: 2 rows, both `text` type.

**Step 3: Commit**

```bash
git add supabase/migrations/20260302_add_instagram_media_id.sql
git commit -m "feat: add instagram_media_id and flag_reason columns to reviews"
```

---

## Task 2: Update dependencies — add resend and jsonwebtoken

**Files:**
- Modify: `netlify/functions/package.json`

**Step 1: Add dependencies**

Update `netlify/functions/package.json` to:

```json
{
  "name": "yvr-water-fountains-functions",
  "version": "1.0.0",
  "description": "Netlify Functions for YVR Water Fountains",
  "dependencies": {
    "@supabase/supabase-js": "^2.38.0",
    "resend": "^3.2.0",
    "jsonwebtoken": "^9.0.2"
  },
  "engines": {
    "node": ">=18"
  }
}
```

**Step 2: Install dependencies**

```bash
cd netlify/functions && npm install
```

Verify `node_modules/resend` and `node_modules/jsonwebtoken` exist.

**Step 3: Commit**

```bash
git add netlify/functions/package.json netlify/functions/package-lock.json
git commit -m "chore: add resend and jsonwebtoken dependencies for Phase 2"
```

---

## Task 3: Shared Instagram utilities for Netlify functions

Port `extractRating()` and `fuzzyMatchFountain()` from `docs/js/link-instagram.js` into a Node.js module that functions can `require()`.

**Files:**
- Create: `netlify/functions/lib/instagram-utils.js`

**Step 1: Create the shared utilities module**

```js
'use strict';

/**
 * Extracts a rating (0-10) from an Instagram caption.
 * Ported from docs/js/link-instagram.js:268-296.
 *
 * Handles: "7/10", "7.5/10", "6-8/10" (averaged), "rating: 7", "score: 8"
 * Returns null if no rating found.
 */
function extractRating(caption) {
  if (!caption) return null;

  // Range pattern: "6-8/10" → average to 7
  const rangeMatch = caption.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)\s*\/\s*10/);
  if (rangeMatch) {
    const low = parseFloat(rangeMatch[1]);
    const high = parseFloat(rangeMatch[2]);
    if (low >= 0 && low <= 10 && high >= 0 && high <= 10) {
      return Math.round(((low + high) / 2) * 10) / 10;
    }
  }

  const patterns = [
    /(\d+\.?\d*)\s*\/\s*10/,
    /(\d+\.?\d*)\s*out\s*of\s*10/i,
    /rating[:\s]*(\d+\.?\d*)/i,
    /score[:\s]*(\d+\.?\d*)/i
  ];

  for (const pattern of patterns) {
    const match = caption.match(pattern);
    if (match) {
      const num = parseFloat(match[1]);
      if (num >= 0 && num <= 10) return num;
    }
  }

  return null;
}

/**
 * Fuzzy-matches a caption against an array of fountain rows from Supabase.
 * Ported from docs/js/link-instagram.js:228-266.
 *
 * Each fountain row should have: { id, name, neighbourhood }
 * Returns array of { fountain, score } sorted by score descending. Empty if no matches.
 */
function fuzzyMatchFountains(caption, fountainRows) {
  const words = caption.toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length > 2);

  const uniqueWords = [...new Set(words)];

  const scored = fountainRows.map(fountain => {
    const name = (fountain.name || '').toLowerCase();
    const neighbourhood = (fountain.neighbourhood || '').toLowerCase();
    const target = name + ' ' + neighbourhood;

    let score = 0;
    for (const word of uniqueWords) {
      if (target.includes(word)) {
        score += name.includes(word) ? 3 : 1;
      }
    }

    // Bigram bonus: consecutive words that appear together in the name
    for (let i = 0; i < uniqueWords.length - 1; i++) {
      const bigram = uniqueWords[i] + ' ' + uniqueWords[i + 1];
      if (name.includes(bigram)) score += 5;
    }

    return { fountain, score };
  });

  return scored
    .filter(s => s.score > 0)
    .sort((a, b) => b.score - a.score);
}

module.exports = { extractRating, fuzzyMatchFountains };
```

**Step 2: Verify the module loads**

```bash
cd netlify/functions && node -e "const u = require('./lib/instagram-utils'); console.log('extractRating:', u.extractRating('Great fountain 7.5/10')); console.log('fuzzyMatch type:', typeof u.fuzzyMatchFountains);"
```

Expected output:
```
extractRating: 7.5
fuzzyMatch type: function
```

**Step 3: Commit**

```bash
git add netlify/functions/lib/instagram-utils.js
git commit -m "feat: add shared Instagram utilities (rating extraction, fuzzy matching)"
```

---

## Task 4: JWT token helper for signed email links

**Files:**
- Create: `netlify/functions/lib/tokens.js`

**Step 1: Create the token module**

```js
'use strict';

const jwt = require('jsonwebtoken');

const SECRET = process.env.REVIEW_ACTION_SECRET;
const EXPIRY = '48h';

/**
 * Creates a signed JWT for an email action link.
 * Payload: { reviewId, action }
 * Expires in 48 hours.
 */
function signActionToken(reviewId, action) {
  if (!SECRET) {
    throw new Error('REVIEW_ACTION_SECRET environment variable is not set');
  }
  return jwt.sign({ reviewId, action }, SECRET, { expiresIn: EXPIRY });
}

/**
 * Verifies and decodes a signed JWT.
 * Returns { reviewId, action } or throws if expired/invalid.
 */
function verifyActionToken(token) {
  if (!SECRET) {
    throw new Error('REVIEW_ACTION_SECRET environment variable is not set');
  }
  return jwt.verify(token, SECRET);
}

module.exports = { signActionToken, verifyActionToken };
```

**Step 2: Verify the module loads**

```bash
cd netlify/functions && REVIEW_ACTION_SECRET=test123 node -e "
const t = require('./lib/tokens');
const token = t.signActionToken('abc-123', 'approve');
console.log('token created:', token.length > 0);
const decoded = t.verifyActionToken(token);
console.log('decoded:', decoded.reviewId, decoded.action);
"
```

Expected:
```
token created: true
decoded: abc-123 approve
```

**Step 3: Commit**

```bash
git add netlify/functions/lib/tokens.js
git commit -m "feat: add JWT token helper for signed email action links"
```

---

## Task 5: Resend email helper

**Files:**
- Create: `netlify/functions/lib/email.js`

**Step 1: Create the email module**

```js
'use strict';

const { Resend } = require('resend');

function getResendClient() {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    throw new Error('RESEND_API_KEY environment variable is not set');
  }
  return new Resend(apiKey);
}

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'yvrwaterfountains@gmail.com';
const FROM_EMAIL = 'YVR Water Fountains <onboarding@resend.dev>';
// Note: Replace FROM_EMAIL with your verified domain once set up in Resend,
// e.g., 'notifications@yourdomain.com'. The onboarding@resend.dev address
// works for testing but can only send to the account owner's email.

/**
 * Sends a "new IG post detected" email with confirm/review links.
 *
 * @param {object} opts
 * @param {string} opts.fountainName - matched fountain name (or "No match found")
 * @param {string} opts.externalId - fountain external_id (e.g., "DFPB0004")
 * @param {number|null} opts.rating - extracted rating or null
 * @param {string} opts.caption - Instagram caption (first 200 chars)
 * @param {string} opts.postDate - post date string
 * @param {string} opts.permalink - Instagram post URL
 * @param {string|null} opts.flagReason - why it needs attention, or null
 * @param {string} opts.confirmUrl - signed URL to approve
 * @param {string} opts.rejectUrl - signed URL to reject
 * @param {string} opts.dashboardUrl - URL to moderation dashboard
 */
async function sendNewPostEmail(opts) {
  const resend = getResendClient();

  const isFlagged = Boolean(opts.flagReason);
  const subject = isFlagged
    ? `New IG post needs review — ${opts.flagReason}`
    : `New IG post → ${opts.fountainName} — ${opts.rating}/10`;

  const truncatedCaption = opts.caption && opts.caption.length > 200
    ? opts.caption.slice(0, 200) + '...'
    : opts.caption || '(no caption)';

  const html = isFlagged
    ? buildFlaggedEmailHtml(opts, truncatedCaption)
    : buildCleanEmailHtml(opts, truncatedCaption);

  await resend.emails.send({
    from: FROM_EMAIL,
    to: [ADMIN_EMAIL],
    subject,
    html
  });
}

function buildCleanEmailHtml(opts, truncatedCaption) {
  return `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 500px; margin: 0 auto;">
  <h2 style="color: #198754;">New Instagram Post Detected</h2>
  <div style="background: #f8f9fa; border-radius: 8px; padding: 16px; margin: 16px 0;">
    <p style="margin: 0 0 8px;"><strong>Fountain:</strong> ${escapeHtml(opts.fountainName)} (${escapeHtml(opts.externalId || 'N/A')})</p>
    <p style="margin: 0 0 8px;"><strong>Rating:</strong> ${opts.rating !== null ? opts.rating + '/10' : 'not detected'}</p>
    <p style="margin: 0 0 8px;"><strong>Posted:</strong> ${escapeHtml(opts.postDate || 'unknown')}</p>
    <p style="margin: 0; color: #6c757d; font-size: 14px;">"${escapeHtml(truncatedCaption)}"</p>
  </div>
  ${opts.permalink ? `<p><a href="${escapeHtml(opts.permalink)}">View on Instagram</a></p>` : ''}
  <div style="margin: 24px 0;">
    <a href="${escapeHtml(opts.confirmUrl)}" style="display: inline-block; background: #198754; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600; margin-right: 12px;">Confirm &amp; Publish</a>
    <a href="${escapeHtml(opts.rejectUrl)}" style="display: inline-block; background: #dc3545; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600; margin-right: 12px;">Reject</a>
    <a href="${escapeHtml(opts.dashboardUrl)}" style="display: inline-block; color: #0d6efd; padding: 12px 0; text-decoration: underline;">Open Dashboard</a>
  </div>
  <p style="color: #adb5bd; font-size: 12px;">Links expire in 48 hours.</p>
</div>`;
}

function buildFlaggedEmailHtml(opts, truncatedCaption) {
  return `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 500px; margin: 0 auto;">
  <h2 style="color: #fd7e14;">New Instagram Post Needs Review</h2>
  <div style="background: #fff3cd; border-radius: 8px; padding: 16px; margin: 16px 0;">
    <p style="margin: 0 0 8px;"><strong>Issue:</strong> ${escapeHtml(opts.flagReason)}</p>
    <p style="margin: 0 0 8px;"><strong>Posted:</strong> ${escapeHtml(opts.postDate || 'unknown')}</p>
    <p style="margin: 0; color: #6c757d; font-size: 14px;">"${escapeHtml(truncatedCaption)}"</p>
  </div>
  ${opts.permalink ? `<p><a href="${escapeHtml(opts.permalink)}">View on Instagram</a></p>` : ''}
  <div style="margin: 24px 0;">
    <a href="${escapeHtml(opts.dashboardUrl)}" style="display: inline-block; background: #0d6efd; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600;">Open Dashboard</a>
  </div>
  <p style="color: #adb5bd; font-size: 12px;">This post could not be auto-matched. Use the dashboard to link it manually.</p>
</div>`;
}

/**
 * Sends a warning email when the Instagram token is about to expire.
 */
async function sendTokenExpiryWarning(daysRemaining) {
  const resend = getResendClient();

  await resend.emails.send({
    from: FROM_EMAIL,
    to: [ADMIN_EMAIL],
    subject: `Instagram token expires in ${daysRemaining} days`,
    html: `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 500px; margin: 0 auto;">
  <h2 style="color: #fd7e14;">Instagram Token Expiring Soon</h2>
  <p>Your Instagram access token expires in <strong>${daysRemaining} days</strong>.</p>
  <p>Refresh it at the <a href="https://developers.facebook.com/tools/explorer/">Meta Graph API Explorer</a> or regenerate a long-lived token.</p>
  <p>Until refreshed, new Instagram posts won't be detected.</p>
</div>`
  });
}

function escapeHtml(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = { sendNewPostEmail, sendTokenExpiryWarning };
```

**Step 2: Verify the module loads**

```bash
cd netlify/functions && node -e "const e = require('./lib/email'); console.log('exports:', Object.keys(e));"
```

Expected: `exports: [ 'sendNewPostEmail', 'sendTokenExpiryWarning' ]`

**Step 3: Commit**

```bash
git add netlify/functions/lib/email.js
git commit -m "feat: add Resend email helper for Instagram notifications"
```

---

## Task 6: Build poll-instagram.js — the daily scheduled function

This is the core function. It runs daily, polls the Instagram Graph API, creates pending reviews, and sends notification emails.

**Files:**
- Create: `netlify/functions/poll-instagram.js`

**Step 1: Create the scheduled function**

```js
'use strict';

const { createClient } = require('@supabase/supabase-js');
const { extractRating, fuzzyMatchFountains } = require('./lib/instagram-utils');
const { signActionToken } = require('./lib/tokens');
const { sendNewPostEmail, sendTokenExpiryWarning } = require('./lib/email');

// Netlify Scheduled Function — runs daily via cron in netlify.toml
exports.handler = async function (event, context) {
  console.log('poll-instagram: starting daily check');

  try {
    validateEnv();
    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

    // Step 1: Check token health
    await checkTokenHealth();

    // Step 2: Fetch recent posts from Instagram Graph API
    const posts = await fetchRecentPosts();
    console.log(`poll-instagram: fetched ${posts.length} recent posts`);

    if (posts.length === 0) {
      return { statusCode: 200, body: JSON.stringify({ message: 'No posts found' }) };
    }

    // Step 3: Find which posts are already in the DB
    const mediaIds = posts.map(p => p.id);
    const { data: existing } = await supabase
      .from('reviews')
      .select('instagram_media_id')
      .in('instagram_media_id', mediaIds);

    const existingIds = new Set((existing || []).map(r => r.instagram_media_id));
    const newPosts = posts.filter(p => !existingIds.has(p.id));
    console.log(`poll-instagram: ${newPosts.length} new posts to process`);

    if (newPosts.length === 0) {
      return { statusCode: 200, body: JSON.stringify({ message: 'No new posts' }) };
    }

    // Step 4: Load all fountains for fuzzy matching
    const { data: fountains } = await supabase
      .from('fountains')
      .select('id, external_id, name, neighbourhood');

    // Step 5: Process each new post
    let processed = 0;
    let flagged = 0;

    for (const post of newPosts) {
      const result = await processPost(post, fountains, supabase);
      processed++;
      if (result.flagReason) flagged++;
    }

    const summary = `Processed ${processed} new posts (${flagged} flagged)`;
    console.log(`poll-instagram: ${summary}`);

    return { statusCode: 200, body: JSON.stringify({ message: summary }) };

  } catch (error) {
    console.error('poll-instagram: fatal error', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};

function validateEnv() {
  const required = [
    'SUPABASE_URL',
    'SUPABASE_SERVICE_ROLE_KEY',
    'INSTAGRAM_ACCESS_TOKEN',
    'INSTAGRAM_USER_ID',
    'RESEND_API_KEY',
    'REVIEW_ACTION_SECRET'
  ];
  const missing = required.filter(k => !process.env[k]);
  if (missing.length > 0) {
    throw new Error(`Missing env vars: ${missing.join(', ')}`);
  }
}

async function checkTokenHealth() {
  // Instagram long-lived tokens last 60 days.
  // The /me endpoint returns an error if the token is expired.
  // We attempt a token refresh if it works, to extend its life.
  // If it fails, we send a warning email.
  try {
    const url = `https://graph.instagram.com/me?fields=id,username&access_token=${process.env.INSTAGRAM_ACCESS_TOKEN}`;
    const resp = await fetch(url);

    if (!resp.ok) {
      const body = await resp.json().catch(() => ({}));
      console.error('poll-instagram: token check failed', body);
      await sendTokenExpiryWarning(0);
      throw new Error('Instagram access token is invalid or expired');
    }

    // Try to refresh the token to extend its lifetime
    const refreshUrl = `https://graph.instagram.com/refresh_access_token?grant_type=ig_refresh_token&access_token=${process.env.INSTAGRAM_ACCESS_TOKEN}`;
    const refreshResp = await fetch(refreshUrl);
    if (refreshResp.ok) {
      const refreshData = await refreshResp.json();
      // Note: The refreshed token is in refreshData.access_token.
      // You'd need to manually update it in Netlify env vars if it changes.
      // For now, just log the expiry info.
      const daysRemaining = refreshData.expires_in
        ? Math.floor(refreshData.expires_in / 86400)
        : null;
      console.log(`poll-instagram: token refreshed, expires in ${daysRemaining} days`);

      if (daysRemaining !== null && daysRemaining <= 7) {
        await sendTokenExpiryWarning(daysRemaining);
      }
    }
  } catch (error) {
    if (error.message.includes('invalid or expired')) throw error;
    console.warn('poll-instagram: token health check error (non-fatal)', error.message);
  }
}

async function fetchRecentPosts() {
  const userId = process.env.INSTAGRAM_USER_ID;
  const token = process.env.INSTAGRAM_ACCESS_TOKEN;
  const url = `https://graph.instagram.com/${userId}/media?fields=id,caption,media_url,permalink,timestamp&limit=10&access_token=${token}`;

  const resp = await fetch(url);
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Instagram API error ${resp.status}: ${body}`);
  }

  const data = await resp.json();
  return data.data || [];
}

async function processPost(post, fountains, supabase) {
  const caption = post.caption || '';
  const rating = extractRating(caption);
  const matches = fuzzyMatchFountains(caption, fountains);
  const bestMatch = matches.length > 0 ? matches[0] : null;

  // Determine flag reason (if any)
  let flagReason = null;
  if (!bestMatch) {
    flagReason = 'no fountain match found';
  } else if (rating === null) {
    flagReason = 'no rating in caption';
  }

  const fountainId = bestMatch ? bestMatch.fountain.id : null;
  const postDate = post.timestamp ? post.timestamp.split('T')[0] : null;

  // Insert review
  const payload = {
    fountain_id: fountainId,
    author_type: 'admin',
    status: 'pending',
    rating: rating,
    review_text: caption || null,
    instagram_url: post.permalink || null,
    instagram_image_url: post.media_url || null,
    instagram_caption: caption || null,
    instagram_media_id: post.id,
    reviewer_name: 'yvrwaterfountains',
    visit_date: postDate,
    flag_reason: flagReason
  };

  const { data: inserted, error } = await supabase
    .from('reviews')
    .insert(payload)
    .select('id')
    .single();

  if (error) {
    console.error(`poll-instagram: failed to insert review for post ${post.id}`, error);
    return { flagReason };
  }

  // Build email action URLs
  const siteUrl = process.env.URL || 'https://yvr-water-fountains.netlify.app';
  const confirmToken = signActionToken(inserted.id, 'approve');
  const rejectToken = signActionToken(inserted.id, 'reject');

  const confirmUrl = `${siteUrl}/.netlify/functions/confirm-review?token=${encodeURIComponent(confirmToken)}`;
  const rejectUrl = `${siteUrl}/.netlify/functions/confirm-review?token=${encodeURIComponent(rejectToken)}`;
  const dashboardUrl = `${siteUrl}/moderation_dashboard.html`;

  // Send email
  try {
    await sendNewPostEmail({
      fountainName: bestMatch ? bestMatch.fountain.name : 'No match found',
      externalId: bestMatch ? bestMatch.fountain.external_id : null,
      rating,
      caption,
      postDate,
      permalink: post.permalink,
      flagReason,
      confirmUrl,
      rejectUrl,
      dashboardUrl
    });
  } catch (emailError) {
    console.error(`poll-instagram: email failed for post ${post.id}`, emailError);
    // Don't throw — the review is already saved, email is best-effort
  }

  return { flagReason };
}
```

**Step 2: Verify the module loads (syntax check)**

```bash
cd netlify/functions && node -e "require('./poll-instagram'); console.log('poll-instagram: loads ok');"
```

Expected: `poll-instagram: loads ok` (it won't run the handler, just verify no syntax errors).

**Step 3: Commit**

```bash
git add netlify/functions/poll-instagram.js
git commit -m "feat: add daily Instagram polling function (Graph API + Resend email)"
```

---

## Task 7: Build confirm-review.js — email action handler

**Files:**
- Create: `netlify/functions/confirm-review.js`

**Step 1: Create the function**

```js
'use strict';

const { createClient } = require('@supabase/supabase-js');
const { verifyActionToken } = require('./lib/tokens');

exports.handler = async function (event) {
  // Only GET (email links are clicked, not POSTed)
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: corsHeaders(), body: '' };
  }

  const token = event.queryStringParameters && event.queryStringParameters.token;
  if (!token) {
    return htmlResponse(400, 'Missing token', 'This link is incomplete. Use the moderation dashboard instead.');
  }

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY || !process.env.REVIEW_ACTION_SECRET) {
    return htmlResponse(500, 'Server Error', 'Server is not configured. Contact the site admin.');
  }

  let payload;
  try {
    payload = verifyActionToken(token);
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return htmlResponse(410, 'Link Expired', 'This link has expired (48-hour limit). Use the moderation dashboard to take action.');
    }
    return htmlResponse(400, 'Invalid Link', 'This link is invalid. Use the moderation dashboard instead.');
  }

  const { reviewId, action } = payload;
  if (!reviewId || !['approve', 'reject'].includes(action)) {
    return htmlResponse(400, 'Invalid Action', 'Unrecognized action. Use the moderation dashboard.');
  }

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

  // Check current review status to avoid double-actions
  const { data: review, error: fetchError } = await supabase
    .from('reviews')
    .select('id, status')
    .eq('id', reviewId)
    .maybeSingle();

  if (fetchError || !review) {
    return htmlResponse(404, 'Not Found', 'This review no longer exists.');
  }

  if (review.status === 'approved' && action === 'approve') {
    return htmlResponse(200, 'Already Approved', 'This review was already approved and is live on the map.');
  }

  if (review.status === 'rejected' && action === 'reject') {
    return htmlResponse(200, 'Already Rejected', 'This review was already rejected.');
  }

  // Perform the action
  const newStatus = action === 'approve' ? 'approved' : 'rejected';
  const updatePayload = { status: newStatus };
  if (action === 'approve') {
    updatePayload.reviewed_at = new Date().toISOString();
  }

  const { error: updateError } = await supabase
    .from('reviews')
    .update(updatePayload)
    .eq('id', reviewId);

  if (updateError) {
    console.error('confirm-review: update failed', updateError);
    return htmlResponse(500, 'Update Failed', 'Could not update the review. Try the moderation dashboard.');
  }

  if (action === 'approve') {
    return htmlResponse(200, 'Review Approved', 'The review is now live on the map. You can close this tab.');
  } else {
    return htmlResponse(200, 'Review Rejected', 'The review has been rejected. You can close this tab.');
  }
};

function htmlResponse(statusCode, title, message) {
  const color = statusCode === 200 ? '#198754' : '#dc3545';
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)} — YVR Water Fountains</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; background: #f8f9fa; }
    .card { background: white; border-radius: 12px; padding: 40px; text-align: center; max-width: 400px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
    h1 { color: ${color}; font-size: 1.5rem; margin: 0 0 12px; }
    p { color: #495057; margin: 0; }
    a { color: #0d6efd; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(message)}</p>
    <p style="margin-top: 16px;"><a href="/map.html">View the map</a></p>
  </div>
</body>
</html>`;

  return {
    statusCode,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
    body: html
  };
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, OPTIONS'
  };
}

function escapeHtml(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
```

**Step 2: Verify it loads**

```bash
cd netlify/functions && node -e "require('./confirm-review'); console.log('confirm-review: loads ok');"
```

**Step 3: Commit**

```bash
git add netlify/functions/confirm-review.js
git commit -m "feat: add confirm-review function for email action links"
```

---

## Task 8: One-time backfill script

This runs once to update the 42 existing reviews with Instagram URLs and photos from the Graph API.

**Files:**
- Create: `scripts/backfill-instagram-urls.js`

**Step 1: Create the backfill script**

```js
#!/usr/bin/env node
'use strict';

/**
 * One-time backfill script: fetches all posts from Instagram Graph API,
 * matches them to existing reviews by caption, and updates instagram_url,
 * instagram_image_url, and instagram_media_id.
 *
 * Usage:
 *   INSTAGRAM_ACCESS_TOKEN=xxx INSTAGRAM_USER_ID=yyy \
 *   SUPABASE_URL=zzz SUPABASE_SERVICE_ROLE_KEY=www \
 *   node scripts/backfill-instagram-urls.js [--dry-run]
 *
 * --dry-run: prints what would be updated without writing to the database.
 */

const { createClient } = require('@supabase/supabase-js');

const DRY_RUN = process.argv.includes('--dry-run');

async function main() {
  validateEnv();

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

  console.log('Fetching all Instagram posts via Graph API...');
  const posts = await fetchAllPosts();
  console.log(`Fetched ${posts.length} posts total.`);

  console.log('Loading existing reviews from Supabase...');
  const { data: reviews, error } = await supabase
    .from('reviews')
    .select('id, instagram_caption, instagram_url, instagram_media_id')
    .eq('author_type', 'admin')
    .eq('status', 'approved');

  if (error) throw error;
  console.log(`Found ${reviews.length} admin reviews.`);

  // Match posts to reviews by caption similarity
  let updated = 0;
  let skipped = 0;
  let noMatch = 0;

  for (const review of reviews) {
    // Skip if already has instagram_media_id (already backfilled)
    if (review.instagram_media_id) {
      skipped++;
      continue;
    }

    const caption = review.instagram_caption || '';
    if (!caption) {
      console.log(`  SKIP review ${review.id}: no caption stored`);
      skipped++;
      continue;
    }

    // Find matching post by caption similarity
    const match = findBestCaptionMatch(caption, posts);
    if (!match) {
      console.log(`  NO MATCH for review ${review.id}: "${caption.slice(0, 60)}..."`);
      noMatch++;
      continue;
    }

    console.log(`  MATCH review ${review.id} → post ${match.id} (score: ${match.score})`);
    console.log(`    permalink: ${match.permalink}`);

    if (!DRY_RUN) {
      const { error: updateError } = await supabase
        .from('reviews')
        .update({
          instagram_url: match.permalink || null,
          instagram_image_url: match.media_url || null,
          instagram_media_id: match.id
        })
        .eq('id', review.id);

      if (updateError) {
        console.error(`    UPDATE FAILED: ${updateError.message}`);
      } else {
        updated++;
      }
    } else {
      updated++;
    }
  }

  console.log(`\nDone${DRY_RUN ? ' (DRY RUN)' : ''}. Updated: ${updated}, Skipped: ${skipped}, No match: ${noMatch}`);
}

function validateEnv() {
  const required = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'INSTAGRAM_ACCESS_TOKEN', 'INSTAGRAM_USER_ID'];
  const missing = required.filter(k => !process.env[k]);
  if (missing.length > 0) {
    console.error(`Missing env vars: ${missing.join(', ')}`);
    process.exit(1);
  }
}

async function fetchAllPosts() {
  const userId = process.env.INSTAGRAM_USER_ID;
  const token = process.env.INSTAGRAM_ACCESS_TOKEN;
  let url = `https://graph.instagram.com/${userId}/media?fields=id,caption,media_url,permalink,timestamp&limit=50&access_token=${token}`;

  const allPosts = [];
  while (url) {
    const resp = await fetch(url);
    if (!resp.ok) {
      const body = await resp.text();
      throw new Error(`Instagram API error ${resp.status}: ${body}`);
    }
    const data = await resp.json();
    allPosts.push(...(data.data || []));
    url = data.paging && data.paging.next ? data.paging.next : null;
  }

  return allPosts;
}

/**
 * Simple caption matching: normalize both captions and compare.
 * Returns the best matching post with a similarity score, or null.
 */
function findBestCaptionMatch(reviewCaption, posts) {
  const normalizedReview = normalize(reviewCaption);

  let bestPost = null;
  let bestScore = 0;

  for (const post of posts) {
    const normalizedPost = normalize(post.caption || '');
    if (!normalizedPost) continue;

    // Try exact match first (after normalization)
    if (normalizedReview === normalizedPost) {
      return { ...post, score: 100 };
    }

    // Word overlap score
    const reviewWords = new Set(normalizedReview.split(/\s+/));
    const postWords = normalizedPost.split(/\s+/);
    let overlap = 0;
    for (const word of postWords) {
      if (reviewWords.has(word)) overlap++;
    }

    // Score = overlap / max(lengths) to normalize
    const score = overlap / Math.max(reviewWords.size, postWords.length);
    if (score > bestScore && score > 0.5) {
      bestScore = score;
      bestPost = { ...post, score: Math.round(score * 100) };
    }
  }

  return bestPost;
}

function normalize(text) {
  return text.toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
}

main().catch(err => {
  console.error('Backfill failed:', err);
  process.exit(1);
});
```

**Step 2: Verify it loads**

```bash
node -e "console.log('syntax check'); require('./scripts/backfill-instagram-urls.js');" 2>&1 || echo "Expected: fails on missing env vars (that's OK — syntax is fine if the error is about env vars)"
```

It should fail with "Missing env vars" — that confirms the syntax is correct.

**Step 3: Commit**

```bash
git add scripts/backfill-instagram-urls.js
git commit -m "feat: add one-time backfill script for Instagram URLs via Graph API"
```

---

## Task 9: Update netlify.toml — scheduled function config

**Files:**
- Modify: `netlify.toml`

**Step 1: Add scheduled function configuration**

Add the following to the end of `netlify.toml` (before any trailing newline):

```toml
# Scheduled function: poll Instagram daily at 8am Pacific (4pm UTC)
[functions."poll-instagram"]
  schedule = "0 16 * * *"
```

Also add a redirect for the confirm-review function:

```toml
[[redirects]]
  from = "/confirm-review"
  to = "/.netlify/functions/confirm-review"
  status = 200
```

**Step 2: Verify the TOML is valid**

```bash
node -e "
const fs = require('fs');
const content = fs.readFileSync('netlify.toml', 'utf8');
console.log('netlify.toml length:', content.length, 'bytes');
// Just check it's not empty and has the new sections
console.log('has schedule:', content.includes('schedule'));
console.log('has confirm-review redirect:', content.includes('confirm-review'));
"
```

**Step 3: Commit**

```bash
git add netlify.toml
git commit -m "feat: configure daily Instagram polling schedule and confirm-review redirect"
```

---

## Task 10: Clean up old broken Netlify functions

The old `submit-review.js` and `manage-rating.js` reference the old `ratings` table and old columns. They are not called by anything in the current codebase. Delete them, and also delete `trigger-deployment.js` since we no longer use a build pipeline.

**Files:**
- Delete: `netlify/functions/submit-review.js`
- Delete: `netlify/functions/manage-rating.js`
- Delete: `netlify/functions/trigger-deployment.js`

**Step 1: Delete the files**

```bash
git rm netlify/functions/submit-review.js netlify/functions/manage-rating.js netlify/functions/trigger-deployment.js
```

**Step 2: Verify no remaining references**

Search for any imports of these files:

```bash
grep -r "trigger-deployment\|submit-review\|manage-rating" netlify/functions/ --include="*.js" || echo "No references found — clean."
```

Also check `netlify.toml` for the old submit-review redirect (line 39-40). Remove it if present — it will be replaced by the new function later in a community-forms phase.

**Step 3: Remove the old submit-review redirect from netlify.toml**

Remove these lines from `netlify.toml`:

```toml
[[redirects]]
  from = "/submit-review"
  to = "/.netlify/functions/submit-review"
  status = 200
```

**Step 4: Commit**

```bash
git add -A netlify/functions/ netlify.toml
git commit -m "chore: remove broken Phase 0 Netlify functions (submit-review, manage-rating, trigger-deployment)"
```

---

## Task 11: End-to-end testing checklist

This is a manual verification task. No new code, just confirming everything works together.

**Prerequisites before testing:**
- [ ] Instagram account switched to Business/Creator
- [ ] Meta Developer App registered, access token generated
- [ ] Resend account created, API key obtained
- [ ] All env vars set in Netlify (see Task 1 in design doc)
- [ ] Database migration applied (Task 1 of this plan)

**Test 1: Verify poll-instagram function locally**

```bash
cd /path/to/repo && npx netlify dev
```

Then in another terminal:

```bash
curl http://localhost:8888/.netlify/functions/poll-instagram
```

Check the Netlify dev server logs for output. It should fetch posts, match fountains, and attempt to send emails.

**Test 2: Verify confirm-review function locally**

Generate a test token:

```bash
cd netlify/functions && REVIEW_ACTION_SECRET=your-secret node -e "
const t = require('./lib/tokens');
// Use a real review ID from your DB for a proper test
const token = t.signActionToken('some-review-uuid', 'approve');
console.log('Test URL: http://localhost:8888/.netlify/functions/confirm-review?token=' + encodeURIComponent(token));
"
```

Open the URL in a browser. It should show "Review Approved" (or a review-not-found error if the UUID is fake).

**Test 3: Run backfill with --dry-run**

```bash
INSTAGRAM_ACCESS_TOKEN=xxx INSTAGRAM_USER_ID=yyy \
SUPABASE_URL=https://hnyktzfyquvmpthfwpvd.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=zzz \
node scripts/backfill-instagram-urls.js --dry-run
```

Check the output: should show matches for the 42 reviews.

**Test 4: Run backfill for real**

```bash
# Same as above, without --dry-run
node scripts/backfill-instagram-urls.js
```

Verify in Supabase that `instagram_url` and `instagram_image_url` are now populated for the 42 reviews.

**Test 5: Deploy to Netlify and verify scheduled function**

Push to main, then check Netlify dashboard → Functions → poll-instagram. It should show the schedule. You can trigger it manually from the Netlify dashboard to test.

---

## Summary of all new/modified files

| Action | File | Purpose |
|--------|------|---------|
| Create | `supabase/migrations/20260302_add_instagram_media_id.sql` | DB migration |
| Modify | `netlify/functions/package.json` | Add resend, jsonwebtoken deps |
| Create | `netlify/functions/lib/instagram-utils.js` | Shared rating extraction + fuzzy matching |
| Create | `netlify/functions/lib/tokens.js` | JWT sign/verify for email links |
| Create | `netlify/functions/lib/email.js` | Resend email templates |
| Create | `netlify/functions/poll-instagram.js` | Daily scheduled Instagram polling |
| Create | `netlify/functions/confirm-review.js` | Email action link handler |
| Create | `scripts/backfill-instagram-urls.js` | One-time URL backfill |
| Modify | `netlify.toml` | Schedule config + redirect |
| Delete | `netlify/functions/submit-review.js` | Old broken function |
| Delete | `netlify/functions/manage-rating.js` | Old broken function |
| Delete | `netlify/functions/trigger-deployment.js` | Old broken function |
