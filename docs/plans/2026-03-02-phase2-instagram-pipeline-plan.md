# Phase 2: Instagram → Map Pipeline — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make it dead simple to add Instagram reviews to the map (paste URL + caption, auto-fill, confirm), backfill the 42 existing reviews with missing Instagram URLs, and send a weekly email reminder to check for new posts.

**Architecture:** Enhance the existing admin review form with auto-extraction (rating from caption, fuzzy fountain matching). Build a backfill tool page for pasting missing URLs. Add a weekly Netlify Scheduled Function for email reminders via Resend. No external APIs, no Facebook.

**Tech Stack:** Vanilla JS (IIFE modules, no bundler), Leaflet maps, Supabase (Postgres + anon key for browser, service role key for functions), Netlify Scheduled Functions, Resend (email), Bootstrap 5

**Design doc:** `docs/plans/2026-03-02-phase2-instagram-pipeline-design.md`

---

## Context for the implementer

### Project structure

- All served files live under `docs/` (Netlify publish dir)
- Netlify functions live in `netlify/functions/` with their own `package.json`
- Browser JS uses IIFE modules attached to `window` (e.g., `window.AppApi`)
- No build step, no bundler — esbuild only bundles Netlify functions
- Script load order: Supabase CDN → env.local.js → config.js → api.js → ui.js → fountain-data.js → page JS
- Local dev: `cd docs && python3 -m http.server 8000`

### Key files you'll reference

- `docs/js/admin-review-form.js` — current admin form logic (auth, map, form submission)
- `docs/admin_review_form.html` — admin form HTML
- `docs/js/link-instagram.js:228-296` — `fuzzyMatchFountains()` and `extractRating()` to reuse
- `docs/js/api.js` — Supabase client helpers (browser-side)
- `docs/js/fountain-data.js` — loads fountain GeoJSON data
- `netlify/functions/package.json` — function dependencies
- `netlify.toml` — build config, function config

### Supabase details

- **Anon key**: in `docs/config.js` (safe, RLS protects writes)
- **Service role key**: Netlify env var only (bypasses RLS, for functions)
- **Reviews table columns** (after Phase 1): `id, fountain_id, author_type, status, rating, review_text, reviewer_name, reviewer_email, instagram_url, instagram_image_url, instagram_caption, visit_date, reviewed_at, approved_by, created_at, updated_at`
- **RLS**: anon can SELECT approved reviews and INSERT pending public reviews. Authenticated admins can do everything.

### Codebase conventions

- Use `const`/`let` (NOT `var`)
- IIFE modules attached to `window`
- Function declarations preferred over arrow functions in module-level code
- `escapeHtml()` is duplicated across files (acceptable for now)

---

## Task 1: Enhance admin form — auto-extract rating from caption

When the admin types or pastes a caption, the rating field auto-fills with the extracted rating.

**Files:**
- Modify: `docs/js/admin-review-form.js`

**Step 1: Add the `extractRating` function**

Add this function inside the IIFE (before `collectFormData`), ported from `docs/js/link-instagram.js:268-296`:

```js
function extractRating(caption) {
  if (!caption) return null;

  var rangeMatch = caption.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)\s*\/\s*10/);
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
```

**Step 2: Wire up the auto-extraction**

In the `init()` function, after the existing `setupReviewForm()` call, add a listener on the caption textarea:

```js
const captionField = document.getElementById('instagramCaption');
if (captionField) {
  captionField.addEventListener('input', function () {
    const rating = extractRating(captionField.value);
    if (rating !== null) {
      const ratingField = document.getElementById('overallRating');
      if (ratingField && !ratingField.dataset.manuallyEdited) {
        ratingField.value = rating;
      }
    }
  });

  const ratingField = document.getElementById('overallRating');
  if (ratingField) {
    ratingField.addEventListener('input', function () {
      ratingField.dataset.manuallyEdited = 'true';
    });
  }
}
```

The `manuallyEdited` flag prevents overwriting a rating the admin has intentionally changed.

**Step 3: Test manually**

1. Start local dev server: `cd docs && python3 -m http.server 8000`
2. Open `http://localhost:8000/admin_review_form.html`
3. Sign in with admin credentials
4. In the caption field, type: `Great fountain at Stanley Park! 7.5/10 would come again`
5. Verify the rating field auto-fills with `7.5`
6. Manually change the rating to `8`
7. Type more in the caption — verify the rating stays at `8` (manual override respected)

**Step 4: Commit**

```bash
git add docs/js/admin-review-form.js
git commit -m "feat: auto-extract rating from caption in admin review form"
```

---

## Task 2: Enhance admin form — auto-match fountain from caption

When the admin types or pastes a caption, the system fuzzy-matches a fountain and auto-selects it on the map.

**Files:**
- Modify: `docs/js/admin-review-form.js`

**Step 1: Add the `fuzzyMatchFountains` function**

Add this function inside the IIFE (after `extractRating`), ported from `docs/js/link-instagram.js:228-266`:

```js
function fuzzyMatchFountains(caption, fountainFeatures) {
  const words = caption.toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(function (w) { return w.length > 2; });

  const uniqueWords = [];
  const seen = {};
  words.forEach(function (w) {
    if (!seen[w]) { seen[w] = true; uniqueWords.push(w); }
  });

  const scored = fountainFeatures.map(function (feature) {
    const props = feature.properties || {};
    const name = (props.name || '').toLowerCase();
    const neighbourhood = (props.neighborhood || '').toLowerCase();
    const location = (props.location || '').toLowerCase();
    const target = name + ' ' + neighbourhood + ' ' + location;

    let score = 0;
    uniqueWords.forEach(function (word) {
      if (target.includes(word)) {
        score += name.includes(word) ? 3 : 1;
      }
    });

    for (let i = 0; i < uniqueWords.length - 1; i++) {
      const bigram = uniqueWords[i] + ' ' + uniqueWords[i + 1];
      if (name.includes(bigram)) score += 5;
    }

    return { feature: feature, score: score };
  });

  return scored
    .filter(function (s) { return s.score > 0; })
    .sort(function (a, b) { return b.score - a.score; });
}
```

**Step 2: Wire up auto-matching on caption change**

Extend the caption `input` listener added in Task 1. After the rating extraction, add fountain matching. Use a debounce to avoid thrashing the map on every keystroke:

```js
let matchDebounce = null;

captionField.addEventListener('input', function () {
  // Rating auto-extraction (from Task 1)
  const rating = extractRating(captionField.value);
  if (rating !== null) {
    const ratingField = document.getElementById('overallRating');
    if (ratingField && !ratingField.dataset.manuallyEdited) {
      ratingField.value = rating;
    }
  }

  // Fountain auto-matching (debounced)
  clearTimeout(matchDebounce);
  matchDebounce = setTimeout(function () {
    const caption = captionField.value.trim();
    if (caption.length < 5 || state.fountains.length === 0) return;

    const matches = fuzzyMatchFountains(caption, state.fountains);
    if (matches.length > 0 && matches[0].score >= 3) {
      const best = matches[0];
      const props = best.feature.properties || {};
      const marker = state.markerById.get(props.id);
      if (marker) {
        state.map.setView(marker.getLatLng(), 16);
        selectFountain(props, marker);
        showFormAlert(
          'Auto-matched: ' + escapeHtml(props.name || 'Unnamed') +
          (matches.length > 1 ? ' (' + (matches.length - 1) + ' other possible matches)' : ''),
          'info'
        );
      }
    }
  }, 500);
});
```

Note: `state.fountains` contains the GeoJSON features loaded in `loadFountains()`. The `selectFountain()` and `state.markerById` already exist in the current code.

**Step 3: Test manually**

1. Open admin form, sign in
2. In the caption field, paste a known caption like: `Hillcrest Park fountain review! Clean water, good pressure. 8/10`
3. Verify: rating auto-fills with `8`, map zooms to Hillcrest area, fountain is selected
4. Verify: info alert shows "Auto-matched: Hillcrest Park (...)"
5. Click a different fountain on the map — verify the selection changes (manual override works)

**Step 4: Commit**

```bash
git add docs/js/admin-review-form.js
git commit -m "feat: auto-match fountain from caption in admin review form"
```

---

## Task 3: Build the backfill tool page — HTML

A simple admin page for pasting Instagram URLs into existing reviews that are missing them.

**Files:**
- Create: `docs/backfill_instagram.html`

**Step 1: Create the HTML page**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backfill Instagram URLs - YVR Water Fountains</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            background: #f5f7fb;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        .page-container {
            max-width: 800px;
            margin: 40px auto;
        }
        .card-header {
            background: linear-gradient(135deg, #007bff, #00c6ff);
            color: #fff;
        }
        .review-card {
            border: 1px solid #e3e6ef;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 16px;
            background: #fff;
            box-shadow: 0 2px 6px rgba(15, 34, 58, 0.08);
        }
        .review-card.saved {
            border-color: #198754;
            background: #f0fdf4;
        }
        .caption-text {
            font-size: 0.9rem;
            color: #495057;
            white-space: pre-wrap;
            max-height: 100px;
            overflow-y: auto;
            margin-bottom: 12px;
            padding: 8px;
            background: #f8f9fa;
            border-radius: 6px;
        }
        .meta {
            font-size: 0.85rem;
            color: #6c757d;
        }
        #adminControls { display: none; }
    </style>
</head>
<body>
<div class="page-container">
    <div class="card shadow-sm mb-4">
        <div class="card-header py-3">
            <h1 class="h4 mb-0">Backfill Instagram URLs</h1>
            <p class="mb-0" style="font-size: 0.9rem;">Paste the Instagram post URL for each review below.</p>
        </div>
        <div class="card-body">
            <div id="authPanel" class="alert alert-warning" role="alert">
                <h5 class="alert-heading">Admin sign in</h5>
                <p id="authMessage">Sign in to load reviews missing Instagram URLs.</p>
                <form id="loginForm" class="row g-3">
                    <div class="col-md-5">
                        <label for="adminEmail" class="form-label">Email</label>
                        <input type="email" id="adminEmail" class="form-control" required>
                    </div>
                    <div class="col-md-5">
                        <label for="adminPassword" class="form-label">Password</label>
                        <input type="password" id="adminPassword" class="form-control" required>
                    </div>
                    <div class="col-md-2 d-flex align-items-end">
                        <button type="submit" class="btn btn-primary w-100">Sign in</button>
                    </div>
                </form>
                <div class="d-flex align-items-center mt-3" id="logoutRow" style="display: none;">
                    <span class="me-3" id="signedInAs"></span>
                    <button class="btn btn-outline-secondary btn-sm" id="logoutButton">Sign out</button>
                </div>
            </div>
            <div id="adminControls">
                <div class="d-flex justify-content-between align-items-center mb-3">
                    <span class="badge bg-primary" id="progressBadge">0 / 0 updated</span>
                    <a href="https://www.instagram.com/yvrwaterfountains/" target="_blank" class="btn btn-outline-secondary btn-sm">
                        Open @yvrwaterfountains
                    </a>
                </div>
                <div id="reviewsContainer"></div>
                <div id="allDone" class="alert alert-success" style="display: none;">
                    All reviews have Instagram URLs. Nothing to backfill!
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.1/dist/umd/supabase.min.js"></script>
<script src="config.js"></script>
<script src="js/api.js"></script>
<script src="js/ui.js"></script>
<script src="js/backfill-instagram.js"></script>
</body>
</html>
```

**Step 2: Commit**

```bash
git add docs/backfill_instagram.html
git commit -m "feat: add backfill Instagram URLs page (HTML)"
```

---

## Task 4: Build the backfill tool — JavaScript

**Files:**
- Create: `docs/js/backfill-instagram.js`

**Step 1: Create the JS module**

```js
'use strict';

(function () {
  const api = window.AppApi || {};
  const ui = window.AppUI || {};
  const state = {
    supabaseClient: null,
    isAdmin: false,
    reviews: [],
    savedCount: 0
  };

  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    if (!api.hasCredentials || !api.hasCredentials()) {
      setAuthMessage('Supabase not configured. Check config.js.');
      return;
    }

    state.supabaseClient = typeof api.getClient === 'function' ? api.getClient() : null;
    if (!state.supabaseClient) {
      setAuthMessage('Supabase client failed to initialize.');
      return;
    }

    setupAuth();

    const { data } = await state.supabaseClient.auth.getSession();
    applySession(data && data.session ? data.session : null);
  }

  function setupAuth() {
    const loginForm = document.getElementById('loginForm');
    const logoutButton = document.getElementById('logoutButton');

    if (loginForm) {
      loginForm.addEventListener('submit', async function (event) {
        event.preventDefault();
        const email = document.getElementById('adminEmail').value.trim();
        const password = document.getElementById('adminPassword').value;
        if (!email || !password) {
          setAuthMessage('Enter both email and password.');
          return;
        }
        try {
          const { error } = await state.supabaseClient.auth.signInWithPassword({ email, password });
          if (error) {
            setAuthMessage('Sign in failed: ' + error.message);
          }
        } catch (error) {
          setAuthMessage('Sign in failed due to a network issue.');
        }
      });
    }

    if (logoutButton) {
      logoutButton.addEventListener('click', function () {
        state.supabaseClient.auth.signOut();
      });
    }

    state.supabaseClient.auth.onAuthStateChange(function (_event, session) {
      applySession(session);
    });
  }

  async function applySession(session) {
    const loginForm = document.getElementById('loginForm');
    const logoutRow = document.getElementById('logoutRow');
    const signedInAs = document.getElementById('signedInAs');
    const adminControls = document.getElementById('adminControls');

    state.isAdmin = false;

    if (!session) {
      setAuthMessage('Sign in to load reviews.');
      if (loginForm) loginForm.style.display = 'block';
      if (logoutRow) logoutRow.style.display = 'none';
      if (adminControls) adminControls.style.display = 'none';
      return;
    }

    if (loginForm) loginForm.style.display = 'none';
    if (logoutRow) logoutRow.style.display = 'flex';
    if (signedInAs) signedInAs.textContent = 'Signed in as ' + session.user.email;

    try {
      const profile = await api.fetchAdminProfile(session.user.id, state.supabaseClient);
      if (!profile) {
        setAuthMessage('Not authorized. Ask the owner to add you to the admins table.');
        return;
      }
      state.isAdmin = true;
      setAuthMessage('Signed in as ' + (profile.display_name || session.user.email));
      const authPanel = document.getElementById('authPanel');
      if (authPanel) {
        authPanel.classList.remove('alert-warning');
        authPanel.classList.add('alert-success');
      }
      if (adminControls) adminControls.style.display = 'block';
      await loadReviews();
    } catch (error) {
      setAuthMessage('Could not verify admin access.');
    }
  }

  async function loadReviews() {
    const container = document.getElementById('reviewsContainer');
    const allDone = document.getElementById('allDone');
    if (!container) return;

    container.innerHTML = '<p class="text-muted">Loading reviews...</p>';

    const { data, error } = await state.supabaseClient
      .from('reviews')
      .select('id, fountain_id, instagram_caption, instagram_url, rating, visit_date, reviewer_name, fountains(name, external_id, neighbourhood)')
      .eq('author_type', 'admin')
      .eq('status', 'approved')
      .is('instagram_url', null)
      .order('visit_date', { ascending: true });

    if (error) {
      container.innerHTML = '<p class="text-danger">Failed to load reviews: ' + escapeHtml(error.message) + '</p>';
      return;
    }

    state.reviews = data || [];
    state.savedCount = 0;

    if (state.reviews.length === 0) {
      container.innerHTML = '';
      if (allDone) allDone.style.display = 'block';
      updateProgress();
      return;
    }

    if (allDone) allDone.style.display = 'none';
    container.innerHTML = '';

    state.reviews.forEach(function (review, index) {
      container.appendChild(buildCard(review, index));
    });

    updateProgress();
  }

  function buildCard(review, index) {
    const fountain = review.fountains || {};
    const card = document.createElement('div');
    card.className = 'review-card';
    card.id = 'review-card-' + index;

    const caption = review.instagram_caption || '(no caption stored)';
    const truncated = caption.length > 300 ? caption.slice(0, 300) + '...' : caption;

    card.innerHTML =
      '<div class="d-flex justify-content-between align-items-start mb-2">' +
        '<div>' +
          '<strong>' + escapeHtml(fountain.name || 'Unknown fountain') + '</strong>' +
          '<span class="meta ms-2">' + escapeHtml(fountain.external_id || '') + '</span>' +
        '</div>' +
        '<span class="badge bg-secondary">' + (review.rating !== null ? review.rating + '/10' : 'no rating') + '</span>' +
      '</div>' +
      '<div class="caption-text">' + escapeHtml(truncated) + '</div>' +
      '<div class="meta mb-2">Visited: ' + escapeHtml(review.visit_date || 'unknown') + '</div>' +
      '<div class="input-group">' +
        '<input type="url" class="form-control" id="url-input-' + index + '" ' +
          'placeholder="Paste Instagram URL here...">' +
        '<button class="btn btn-outline-success" id="save-btn-' + index + '">Save</button>' +
      '</div>' +
      '<div id="save-status-' + index + '" class="mt-2"></div>';

    const saveBtn = card.querySelector('#save-btn-' + index);
    saveBtn.addEventListener('click', function () {
      saveUrl(review, index);
    });

    const urlInput = card.querySelector('#url-input-' + index);
    urlInput.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        saveUrl(review, index);
      }
    });

    return card;
  }

  async function saveUrl(review, index) {
    const input = document.getElementById('url-input-' + index);
    const btn = document.getElementById('save-btn-' + index);
    const status = document.getElementById('save-status-' + index);
    const card = document.getElementById('review-card-' + index);
    const url = input ? input.value.trim() : '';

    if (!url) {
      if (status) status.innerHTML = '<small class="text-danger">Enter a URL first.</small>';
      return;
    }

    if (!url.includes('instagram.com/')) {
      if (status) status.innerHTML = '<small class="text-danger">Not a valid Instagram URL.</small>';
      return;
    }

    if (btn) { btn.disabled = true; btn.textContent = 'Saving...'; }

    const { error } = await state.supabaseClient
      .from('reviews')
      .update({ instagram_url: url })
      .eq('id', review.id);

    if (error) {
      if (status) status.innerHTML = '<small class="text-danger">Save failed: ' + escapeHtml(error.message) + '</small>';
      if (btn) { btn.disabled = false; btn.textContent = 'Save'; }
      return;
    }

    state.savedCount++;
    if (card) card.classList.add('saved');
    if (input) { input.disabled = true; input.value = url; }
    if (btn) { btn.disabled = true; btn.textContent = 'Saved'; btn.classList.replace('btn-outline-success', 'btn-success'); }
    if (status) status.innerHTML = '<small class="text-success">Saved!</small>';

    updateProgress();
  }

  function updateProgress() {
    const badge = document.getElementById('progressBadge');
    if (badge) {
      badge.textContent = state.savedCount + ' / ' + state.reviews.length + ' updated';
    }
  }

  function setAuthMessage(message) {
    const el = document.getElementById('authMessage');
    if (el) el.textContent = message;
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
})();
```

**Step 2: Test manually**

1. Open `http://localhost:8000/backfill_instagram.html`
2. Sign in with admin credentials
3. Verify: reviews with missing URLs are listed with captions, ratings, fountain names
4. Open `https://www.instagram.com/yvrwaterfountains/` in another tab
5. Find a matching post, copy its URL
6. Paste into the input field, click Save
7. Verify: card turns green, "Saved!" appears, progress counter updates

**Step 3: Commit**

```bash
git add docs/js/backfill-instagram.js
git commit -m "feat: add backfill Instagram URLs tool (JavaScript)"
```

---

## Task 5: Add Resend dependency + weekly reminder function

**Files:**
- Modify: `netlify/functions/package.json`
- Create: `netlify/functions/weekly-reminder.js`
- Modify: `netlify.toml`

**Step 1: Add Resend dependency**

Update `netlify/functions/package.json`:

```json
{
  "name": "yvr-water-fountains-functions",
  "version": "1.0.0",
  "description": "Netlify Functions for YVR Water Fountains",
  "dependencies": {
    "@supabase/supabase-js": "^2.38.0",
    "resend": "^3.2.0"
  },
  "engines": {
    "node": ">=18"
  }
}
```

Install:

```bash
cd netlify/functions && npm install
```

**Step 2: Create the weekly reminder function**

Create `netlify/functions/weekly-reminder.js`:

```js
'use strict';

const { createClient } = require('@supabase/supabase-js');
const { Resend } = require('resend');

// Netlify Scheduled Function — runs weekly (configured in netlify.toml)
exports.handler = async function () {
  console.log('weekly-reminder: starting');

  const missing = [];
  if (!process.env.SUPABASE_URL) missing.push('SUPABASE_URL');
  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!process.env.RESEND_API_KEY) missing.push('RESEND_API_KEY');

  if (missing.length > 0) {
    console.error('weekly-reminder: missing env vars:', missing.join(', '));
    return { statusCode: 500, body: JSON.stringify({ error: 'Missing env vars: ' + missing.join(', ') }) };
  }

  const adminEmail = process.env.ADMIN_EMAIL || 'yvrwaterfountains@gmail.com';

  try {
    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

    // Get counts for the email
    const [fountainResult, reviewedResult, recentResult] = await Promise.all([
      supabase.from('fountains').select('id', { count: 'exact', head: true }),
      supabase.from('reviews').select('id', { count: 'exact', head: true }).eq('status', 'approved'),
      supabase.from('reviews').select('id', { count: 'exact', head: true }).eq('status', 'approved').gte('created_at', sevenDaysAgo())
    ]);

    const totalFountains = fountainResult.count || 0;
    const totalReviews = reviewedResult.count || 0;
    const recentReviews = recentResult.count || 0;

    const siteUrl = process.env.URL || 'https://yvr-water-fountains.netlify.app';

    const resend = new Resend(process.env.RESEND_API_KEY);

    await resend.emails.send({
      from: 'YVR Water Fountains <onboarding@resend.dev>',
      to: [adminEmail],
      subject: 'Weekly reminder — any new fountain reviews?',
      html: buildEmailHtml(totalFountains, totalReviews, recentReviews, siteUrl)
    });

    console.log('weekly-reminder: email sent to', adminEmail);
    return { statusCode: 200, body: JSON.stringify({ message: 'Reminder sent' }) };

  } catch (error) {
    console.error('weekly-reminder: error', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};

function sevenDaysAgo() {
  const date = new Date();
  date.setDate(date.getDate() - 7);
  return date.toISOString();
}

function buildEmailHtml(totalFountains, totalReviews, recentReviews, siteUrl) {
  return `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 500px; margin: 0 auto;">
  <h2 style="color: #198754;">Weekly Fountain Check-In</h2>
  <p>Have you or your friend posted any new <strong>@yvrwaterfountains</strong> reels this week?</p>
  <p>If so, add them to the map — it only takes 30 seconds:</p>
  <div style="margin: 20px 0;">
    <a href="${siteUrl}/admin_review_form.html" style="display: inline-block; background: #198754; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600;">Open Admin Form</a>
  </div>
  <p style="font-size: 14px; color: #6c757d;">Paste the IG URL + caption, and the form auto-fills the rating and fountain match. One click to publish.</p>
  <hr style="border: none; border-top: 1px solid #e9ecef; margin: 24px 0;">
  <div style="font-size: 14px; color: #6c757d;">
    <p style="margin: 4px 0;"><strong>${totalReviews}</strong> reviews on the map</p>
    <p style="margin: 4px 0;"><strong>${totalFountains}</strong> fountains tracked</p>
    <p style="margin: 4px 0;"><strong>${recentReviews}</strong> reviews added this week</p>
  </div>
  <p style="color: #adb5bd; font-size: 12px; margin-top: 20px;">
    <a href="${siteUrl}/map.html" style="color: #adb5bd;">View the map</a>
  </p>
</div>`;
}
```

**Step 3: Add schedule to netlify.toml**

Add to the end of `netlify.toml`:

```toml
# Weekly reminder email — Mondays 10am Pacific (6pm UTC)
[functions."weekly-reminder"]
  schedule = "0 18 * * 1"
```

**Step 4: Verify function loads**

```bash
cd netlify/functions && node -e "require('./weekly-reminder'); console.log('weekly-reminder: loads ok');"
```

**Step 5: Commit**

```bash
git add netlify/functions/package.json netlify/functions/package-lock.json netlify/functions/weekly-reminder.js netlify.toml
git commit -m "feat: add weekly email reminder via Resend scheduled function"
```

---

## Task 6: Clean up old broken Netlify functions

The old functions reference the deleted `ratings` table and old columns. Nothing calls them.

**Files:**
- Delete: `netlify/functions/submit-review.js`
- Delete: `netlify/functions/manage-rating.js`
- Delete: `netlify/functions/trigger-deployment.js`
- Modify: `netlify.toml` (remove old submit-review redirect)

**Step 1: Delete old functions**

```bash
git rm netlify/functions/submit-review.js netlify/functions/manage-rating.js netlify/functions/trigger-deployment.js
```

**Step 2: Remove old redirect from netlify.toml**

Remove these lines from `netlify.toml`:

```toml
[[redirects]]
  from = "/submit-review"
  to = "/.netlify/functions/submit-review"
  status = 200
```

**Step 3: Commit**

```bash
git add -A netlify/ netlify.toml
git commit -m "chore: remove broken legacy Netlify functions and old redirect"
```

---

## Task 7: End-to-end testing

Manual verification checklist — no new code.

**Prerequisites:**
- [ ] Resend account created at resend.com, API key obtained
- [ ] Netlify env vars set: `RESEND_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_EMAIL`

**Test 1: Admin form auto-extraction**
1. Open admin form locally, sign in
2. Paste a caption with a rating → verify rating auto-fills
3. Paste a caption with a fountain name → verify map zooms and selects it
4. Submit a review → verify it appears in Supabase

**Test 2: Backfill tool**
1. Open backfill page, sign in
2. Verify reviews with missing URLs are listed
3. Paste an Instagram URL, save → verify it updates in Supabase
4. Refresh → verify the saved review no longer appears

**Test 3: Weekly reminder (local)**
```bash
cd /path/to/repo && npx netlify dev
```
Then in another terminal:
```bash
curl http://localhost:8888/.netlify/functions/weekly-reminder
```
Check your email for the weekly reminder.

**Test 4: Deploy and verify**
Push to main → check Netlify dashboard → Functions → weekly-reminder should show the Monday schedule.

---

## Summary of all new/modified files

| Action | File | Purpose |
|--------|------|---------|
| Modify | `docs/js/admin-review-form.js` | Auto-extract rating + fuzzy-match fountain from caption |
| Create | `docs/backfill_instagram.html` | Backfill tool page (HTML) |
| Create | `docs/js/backfill-instagram.js` | Backfill tool logic (JS) |
| Modify | `netlify/functions/package.json` | Add Resend dependency |
| Create | `netlify/functions/weekly-reminder.js` | Weekly email reminder function |
| Modify | `netlify.toml` | Add schedule config, remove old redirect |
| Delete | `netlify/functions/submit-review.js` | Old broken function |
| Delete | `netlify/functions/manage-rating.js` | Old broken function |
| Delete | `netlify/functions/trigger-deployment.js` | Old broken function |
