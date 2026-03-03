# Phase 1: Simplify the Core — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Get the map reading live data from Supabase, simplify the schema to one rating per review, and make the site fully functional on Netlify.

**Architecture:** Drop 5 sub-rating columns from the reviews table (keeping just `rating`). Move shared JS into `docs/js/` so Netlify can serve them. Wire `map.html` to load data via `FountainData.fetchGeoData()` which queries Supabase's `fountain_overview_view`. Hardcode the (public) Supabase anon key in `config.js` so the live site works without build-time env injection. Keep static GeoJSON as an emergency fallback, updated with current review data.

**Tech Stack:** Vanilla JS, Leaflet, Supabase (PostgreSQL + RLS), Netlify (static hosting), Bootstrap 5

**Decisions (from user):**
- Skip Netlify functions for now (Phase 2 will rebuild submit-review + manage-rating)
- Keep GeoJSON as fallback, but update it with current review data from Supabase
- Hardcode Supabase credentials in config.js (anon key is public by design)

---

### Task 1: Database migration — drop sub-rating columns

**Why:** The reviews table has 5 sub-rating columns (`water_quality`, `flow_pressure`, `temperature`, `cleanliness`, `accessibility`) that are never used by Instagram reviews and add unnecessary complexity. The simplified schema uses only the single `rating` column.

**Files:**
- Create: `supabase/migrations/20260302_drop_sub_ratings.sql`

**Step 1: Write the migration SQL**

Create `supabase/migrations/20260302_drop_sub_ratings.sql`:

```sql
-- Phase 1: Drop unused sub-rating columns from reviews.
-- All 42 existing reviews use only the single `rating` column.
-- The 5 sub-rating columns were never populated by the Instagram backfill tool.

ALTER TABLE public.reviews
  DROP COLUMN IF EXISTS water_quality,
  DROP COLUMN IF EXISTS flow_pressure,
  DROP COLUMN IF EXISTS temperature,
  DROP COLUMN IF EXISTS cleanliness,
  DROP COLUMN IF EXISTS accessibility;
```

**Step 2: Run the migration in Supabase SQL Editor**

1. Open Supabase dashboard → SQL Editor
2. Paste and run the SQL above
3. Verify: run `SELECT column_name FROM information_schema.columns WHERE table_name = 'reviews' ORDER BY ordinal_position;`
4. Expected: `water_quality`, `flow_pressure`, `temperature`, `cleanliness`, `accessibility` are gone; `rating` remains

**Step 3: Verify existing reviews are intact**

Run in SQL Editor:
```sql
SELECT COUNT(*), ROUND(AVG(rating)::numeric, 1) AS avg_rating
FROM public.reviews
WHERE status = 'approved';
```
Expected: 42 reviews, avg ~6.9

**Step 4: Commit the migration file**

```bash
git add supabase/migrations/20260302_drop_sub_ratings.sql
git commit -m "chore: add migration to drop sub-rating columns from reviews"
```

---

### Task 2: Move shared JS into docs/js/ for Netlify compatibility

**Why:** Netlify publishes `docs/` as the site root. Currently `src/api.js` and `src/ui.js` live outside `docs/`, so `../src/api.js` references 404 on the live site. Moving them into `docs/js/` fixes this and keeps all served files under the publish directory.

**Files:**
- Move: `src/api.js` → `docs/js/api.js`
- Move: `src/ui.js` → `docs/js/ui.js`
- Modify: `docs/link-instagram.html`
- Modify: `docs/admin_review_form.html`
- Modify: `docs/public_review_form.html`
- Modify: `docs/moderation_dashboard.html`

**Step 1: Move the files with git**

```bash
git mv src/api.js docs/js/api.js
git mv src/ui.js docs/js/ui.js
```

**Step 2: Update all HTML references**

In each of the 4 HTML files listed above, change:
```html
<script src="../src/api.js"></script>
<script src="../src/ui.js"></script>
```
to:
```html
<script src="js/api.js"></script>
<script src="js/ui.js"></script>
```

Files and line numbers:
- `docs/link-instagram.html:201-202`
- `docs/admin_review_form.html:382-383`
- `docs/public_review_form.html:469-470`
- `docs/moderation_dashboard.html:93-94`

**Step 3: Verify locally**

Start local server: `python3 -m http.server 8000` (from project root)

Open `http://localhost:8000/docs/admin_review_form.html` — sign in should still work. Open browser console — no 404 errors for api.js or ui.js.

**Step 4: Commit**

```bash
git add docs/js/api.js docs/js/ui.js docs/link-instagram.html docs/admin_review_form.html docs/public_review_form.html docs/moderation_dashboard.html
git commit -m "refactor: move api.js and ui.js into docs/js/ for Netlify compatibility"
```

---

### Task 3: Wire map.html to live Supabase data

**Why:** This is the core deliverable of Phase 1. Currently `map.html` fetches a static GeoJSON file directly. After this change, it loads live data from Supabase (ratings, reviews, Instagram links all appear on the map in real time).

**Files:**
- Modify: `docs/map.html:675-677` (script tags)
- Modify: `docs/js/map.js:40` (data loading in `init()`)
- Modify: `docs/js/map.js:206-212` (remove `loadFountainData` function)

**Step 1: Add required script tags to map.html**

Replace the existing script block at lines 675-677:

```html
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" defer></script>
<script src="config.js" defer></script>
<script src="js/map.js" defer></script>
```

with:

```html
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.1/dist/umd/supabase.min.js"></script>
<script src="env.local.js" onerror="/* no local env */"></script>
<script src="config.js"></script>
<script src="js/api.js"></script>
<script src="js/ui.js"></script>
<script src="js/fountain-data.js"></script>
<script src="js/map.js"></script>
```

Note: removed `defer` because the scripts have load-order dependencies (config must load before api, api before fountain-data, etc.). The scripts are at the end of `<body>` anyway, so `defer` provides no benefit.

**Step 2: Change map.js init() to use FountainData**

In `docs/js/map.js`, replace the `init()` function's data loading block (lines 39-46):

```javascript
    try {
      const data = await loadFountainData(config.GEOJSON_PATH);
      state.fountains = data.features || [];
      placeFountainsOnMap(data);
      focusFromHash();
    } catch (error) {
      handleLoadError(error);
    }
```

with:

```javascript
    try {
      const data = await FountainData.fetchGeoData();
      state.fountains = data.features || [];
      placeFountainsOnMap(data);
      focusFromHash();
    } catch (error) {
      handleLoadError(error);
    }
```

**Step 3: Remove the now-unused loadFountainData function**

Delete the `loadFountainData` function from `docs/js/map.js` (lines 206-212):

```javascript
  async function loadFountainData(path) {
    const response = await fetch(path);
    if (!response.ok) {
      throw new Error(`failed to load fountain data: ${response.status} ${response.statusText}`);
    }
    return response.json();
  }
```

**Step 4: Test locally**

Start local server: `python3 -m http.server 8000` (from project root)

Open `http://localhost:8000/docs/map.html`:
- Map should show 428+ fountain markers
- Click a fountain → popup should show rating, reviewer, Instagram link
- Look for fountains you reviewed (e.g., search for Stanley Park) — they should show ratings from the backfill
- Console should show no errors
- Console should NOT show "falling back to geojson" (Supabase should work)

**Step 5: Commit**

```bash
git add docs/map.html docs/js/map.js
git commit -m "feat: wire map.html to live Supabase data via FountainData"
```

---

### Task 4: Simplify forms — remove sub-rating fields

**Why:** The admin review form, public review form, and moderation dashboard all reference the 5 sub-rating columns we just dropped. Remove them so the forms match the simplified schema.

**Files:**
- Modify: `docs/admin_review_form.html:319-350` (remove 5 sub-rating inputs)
- Modify: `docs/js/admin-review-form.js:379-408` (collectFormData, validateAdminForm, submitAdminReview)
- Modify: `docs/public_review_form.html:313-442` (remove 5 sub-rating radio groups)
- Modify: `docs/js/public-review-form.js:328-345,367-381` (collectFormData, submitReview)
- Modify: `docs/js/moderation-dashboard.js:266-272` (buildReviewCard rating display)
- Modify: `docs/js/api.js:106-107` (fetchReviewsByStatus SELECT)

**Step 1: Simplify admin review form HTML**

In `docs/admin_review_form.html`, replace the rating group (lines 319-350) with just the overall rating:

```html
                            <div class="rating-group">
                                <div class="rating-item">
                                    <label for="overallRating">Rating (0-10)</label>
                                    <input type="number" class="form-control rating-input" id="overallRating"
                                           min="0" max="10" step="0.5" required>
                                </div>
                            </div>
```

**Step 2: Simplify admin-review-form.js**

In `docs/js/admin-review-form.js`:

Replace `collectFormData()` (line 379):
```javascript
  function collectFormData() {
    return {
      instagramUrl: document.getElementById('instagramUrl').value.trim(),
      instagramCaption: document.getElementById('instagramCaption').value.trim(),
      overallRating: document.getElementById('overallRating').value,
      reviewNotes: document.getElementById('reviewNotes').value.trim(),
      visitDate: document.getElementById('visitDate').value
    };
  }
```

Replace `validateAdminForm()` (line 394):
```javascript
  function validateAdminForm(data) {
    if (!data.instagramUrl) {
      return 'add the instagram post url so visitors can see the source.';
    }
    if (!data.overallRating && data.overallRating !== 0) {
      return 'provide a rating on the 0-10 scale.';
    }
    if (!data.visitDate) {
      return 'include the visit date for proper context.';
    }
    return null;
  }
```

Replace `submitAdminReview()` payload (line 416):
```javascript
    const payload = {
      fountain_id: fountainId,
      author_type: 'admin',
      status: 'approved',
      rating: toNumeric(data.overallRating),
      review_text: data.reviewNotes || null,
      instagram_url: data.instagramUrl,
      instagram_caption: data.instagramCaption || null,
      instagram_image_url: buildInstagramImageUrl(data.instagramUrl),
      visit_date: data.visitDate || null
    };
```

(Removed: `water_quality`, `flow_pressure`, `temperature`, `cleanliness`, `accessibility`, `reviewed_at`)

**Step 3: Simplify public review form HTML**

In `docs/public_review_form.html`, replace the entire Ratings section (lines 283-442) with:

```html
                <!-- Ratings -->
                <div class="form-section">
                    <h3><i class="fas fa-star"></i> Rating</h3>

                    <div class="rating-input">
                        <label>Overall Rating (1-10):</label>
                        <div class="rating-scale">
                            <input type="radio" id="overall1" name="overallRating" value="1">
                            <label for="overall1">1</label>
                            <input type="radio" id="overall2" name="overallRating" value="2">
                            <label for="overall2">2</label>
                            <input type="radio" id="overall3" name="overallRating" value="3">
                            <label for="overall3">3</label>
                            <input type="radio" id="overall4" name="overallRating" value="4">
                            <label for="overall4">4</label>
                            <input type="radio" id="overall5" name="overallRating" value="5">
                            <label for="overall5">5</label>
                            <input type="radio" id="overall6" name="overallRating" value="6">
                            <label for="overall6">6</label>
                            <input type="radio" id="overall7" name="overallRating" value="7">
                            <label for="overall7">7</label>
                            <input type="radio" id="overall8" name="overallRating" value="8">
                            <label for="overall8">8</label>
                            <input type="radio" id="overall9" name="overallRating" value="9">
                            <label for="overall9">9</label>
                            <input type="radio" id="overall10" name="overallRating" value="10">
                            <label for="overall10">10</label>
                        </div>
                    </div>
                </div>
```

**Step 4: Simplify public-review-form.js**

In `docs/js/public-review-form.js`:

Replace `collectFormData()` (line 328):
```javascript
  function collectFormData() {
    const form = document.getElementById('reviewForm');
    const formData = new FormData(form);
    return {
      fountainId: document.getElementById('fountainId').value.trim(),
      supabaseFountainId: document.getElementById('fountainSupabaseId').value.trim(),
      reviewerName: document.getElementById('reviewerName').value.trim(),
      reviewerEmail: document.getElementById('reviewerEmail').value.trim(),
      visitDate: document.getElementById('visitDate').value,
      overallRating: formData.get('overallRating'),
      additionalNotes: document.getElementById('additionalNotes').value.trim()
    };
  }
```

Replace `submitReview()` payload (line 368):
```javascript
  async function submitReview(data) {
    const payload = {
      fountain_id: data.supabaseFountainId,
      status: 'pending',
      author_type: 'public',
      reviewer_name: data.reviewerName,
      reviewer_email: data.reviewerEmail || null,
      visit_date: data.visitDate || null,
      rating: toNumeric(data.overallRating),
      review_text: data.additionalNotes || null
    };

    if (!api.insertPublicReview) {
      throw new Error('supabase api helpers are not available');
    }

    await api.insertPublicReview(payload, state.supabaseClient);
  }
```

**Step 5: Simplify moderation dashboard review cards**

In `docs/js/moderation-dashboard.js`, replace the rating display block (lines 266-276):

```javascript
    if (review.rating !== null) {
      rows.push(`<div class="mb-2"><strong>rating:</strong> ${formatScore(review.rating)}</div>`);
    }
```

(Removed: sub-rating lines for water, flow, temp, drainage, access)

**Step 6: Update api.js fetchReviewsByStatus SELECT**

In `docs/js/api.js`, replace the SELECT in `fetchReviewsByStatus` (line 107):

```javascript
      .select('id, fountain_id, reviewer_name, reviewer_email, rating, review_text, instagram_url, visit_date, created_at, author_type')
```

(Removed: `water_quality, flow_pressure, temperature, cleanliness, accessibility`)

**Step 7: Test locally**

1. Open admin review form → should show only one rating field (Overall Rating)
2. Open public review form → should show only one row of 1-10 radio buttons
3. Open moderation dashboard → review cards should show single "rating: X/10" line
4. Console should have no errors about missing fields

**Step 8: Commit**

```bash
git add docs/admin_review_form.html docs/js/admin-review-form.js docs/public_review_form.html docs/js/public-review-form.js docs/js/moderation-dashboard.js docs/js/api.js
git commit -m "feat: simplify forms to single rating — drop sub-rating fields"
```

---

### Task 5: Add production Supabase credentials to config.js

**Why:** Netlify serves static files — there's no server-side env var injection. The Supabase anon key is designed to be public (security comes from RLS policies, not key secrecy). Hardcoding it in `config.js` makes the live site work without any build step.

**Files:**
- Modify: `docs/config.js:22-23`

**Step 1: Update config.js with production defaults**

In `docs/config.js`, replace lines 22-23:

```javascript
    SUPABASE_URL: env.SUPABASE_URL || window.SUPABASE_URL || null,
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY || window.SUPABASE_ANON_KEY || null,
```

with:

```javascript
    SUPABASE_URL: env.SUPABASE_URL || window.SUPABASE_URL || 'https://hnyktzfyquvmpthfwpvd.supabase.co',
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY || window.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhueWt0emZ5cXV2bXB0aGZ3cHZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0OTM2MzIsImV4cCI6MjA4ODA2OTYzMn0.OJJNyTz0LglcJgfGiNNOcy6tmayagXnpSkYnqg6_M6A',
```

The precedence chain stays the same: env vars > window globals (env.local.js) > hardcoded defaults. For local dev, `env.local.js` still overrides. For Netlify, the hardcoded values kick in.

**Step 2: Also update og:url meta tag**

In `docs/map.html`, change line 17:
```html
  <meta property="og:url" content="https://kcarbeck.github.io/yvr-water-fountains/map.html">
```
to:
```html
  <meta property="og:url" content="https://yvr-water-fountains.netlify.app/map.html">
```

**Step 3: Commit**

```bash
git add docs/config.js docs/map.html
git commit -m "feat: add production Supabase credentials to config.js for Netlify"
```

---

### Task 6: Regenerate GeoJSON with review data for fallback

**Why:** The static GeoJSON file has fountain metadata but no review data. The user wants the fallback to include the 42 reviews from Supabase so the map still shows ratings if Supabase is ever down.

**Files:**
- Modify: `docs/data/fountains_processed.geojson`

**Step 1: Export fountain overview from Supabase and convert to GeoJSON**

Run this from the project root. It fetches all fountain data (with review metrics) from the `fountain_overview_view` and generates a GeoJSON file in the same format that `fountain-data.js:transformRecordsToGeojson()` produces:

```bash
curl -s "https://hnyktzfyquvmpthfwpvd.supabase.co/rest/v1/fountain_overview_view?select=*&order=name.asc" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhueWt0emZ5cXV2bXB0aGZ3cHZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0OTM2MzIsImV4cCI6MjA4ODA2OTYzMn0.OJJNyTz0LglcJgfGiNNOcy6tmayagXnpSkYnqg6_M6A" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhueWt0emZ5cXV2bXB0aGZ3cHZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0OTM2MzIsImV4cCI6MjA4ODA2OTYzMn0.OJJNyTz0LglcJgfGiNNOcy6tmayagXnpSkYnqg6_M6A" \
  | python3 -c "
import json, sys
records = json.load(sys.stdin)
features = []
for r in records:
    if r.get('longitude') is None or r.get('latitude') is None:
        continue
    props = {
        'id': r.get('external_id') or r.get('id'),
        'supabase_id': r.get('id'),
        'name': r.get('name'),
        'neighborhood': r.get('neighbourhood'),
        'location': r.get('location_description'),
        'address': r.get('location_description'),
        'city_name': r.get('city_name'),
        'source_name': r.get('source_name'),
        'operational_status': r.get('operational_status'),
        'season_note': r.get('season_note'),
        'pet_friendly': r.get('pet_friendly'),
        'has_bottle_filler': r.get('has_bottle_filler'),
        'is_wheelchair_accessible': r.get('is_wheelchair_accessible'),
        'last_verified_at': r.get('last_verified_at'),
        'avg_rating': float(r['average_rating']) if r.get('average_rating') is not None else None,
        'rating_count': r.get('approved_review_count') or 0,
        'admin_review_count': r.get('admin_review_count') or 0,
        'latest_review_rating': float(r['latest_review_rating']) if r.get('latest_review_rating') is not None else None,
        'latest_review_text': r.get('latest_review_text'),
        'latest_review_author_type': r.get('latest_review_author_type'),
        'latest_review_reviewer_name': r.get('latest_review_reviewer_name'),
        'latest_review_instagram_url': r.get('latest_review_instagram_url'),
        'latest_review_instagram_image_url': r.get('latest_review_instagram_image_url'),
        'latest_review_instagram_caption': r.get('latest_review_instagram_caption'),
        'latest_reviewed_at': r.get('latest_reviewed_at'),
    }
    features.append({
        'type': 'Feature',
        'geometry': {'type': 'Point', 'coordinates': [r['longitude'], r['latitude']]},
        'properties': props
    })
geojson = {'type': 'FeatureCollection', 'features': features}
print(json.dumps(geojson, indent=2))
" > docs/data/fountains_processed.geojson
```

**Step 2: Verify the output**

```bash
python3 -c "import json; f=json.load(open('docs/data/fountains_processed.geojson')); print(f'{len(f[\"features\"])} features'); rated=[x for x in f['features'] if x['properties'].get('avg_rating')]; print(f'{len(rated)} with ratings')"
```

Expected: 428+ features, 42 with ratings (one per reviewed fountain — some fountains may share reviews, so actual count may differ).

**Step 3: Also update the root-level copy if it exists**

```bash
cp docs/data/fountains_processed.geojson data/fountains_processed.geojson 2>/dev/null || true
```

**Step 4: Commit**

```bash
git add docs/data/fountains_processed.geojson data/fountains_processed.geojson
git commit -m "chore: regenerate GeoJSON with review data from Supabase"
```

---

### Task 7: Final testing and push

**Step 1: Test locally end-to-end**

Start server: `python3 -m http.server 8000` (from project root)

1. **Map** (`http://localhost:8000/docs/map.html`):
   - 428+ markers appear
   - Click a reviewed fountain → popup shows avg rating, latest review, Instagram link
   - Click an unreviewed fountain → popup shows "—" for rating fields
   - Console shows NO "falling back to geojson" message (Supabase is working)
   - Mobile simulation (resize browser narrow) → bottom sheet works

2. **Admin review form** (`http://localhost:8000/docs/admin_review_form.html`):
   - Sign in works
   - Only 1 rating field (Overall Rating), no sub-ratings
   - Can select a fountain and submit a test review

3. **Public review form** (`http://localhost:8000/docs/public_review_form.html`):
   - Shows 1 row of 1-10 radio buttons, no sub-ratings
   - Can select a fountain (search + map click)
   - Form validates (requires name, date, rating)

4. **Moderation dashboard** (`http://localhost:8000/docs/moderation_dashboard.html`):
   - Sign in works
   - Review cards show single "rating: X/10"
   - Approve/reject buttons work

**Step 2: Push to origin**

```bash
git push origin main
```

**Step 3: Verify on Netlify**

Wait ~1 minute for Netlify to deploy, then:

1. Open `https://yvr-water-fountains.netlify.app/map.html`
2. Fountains should appear with live Supabase data (ratings, Instagram links)
3. Click a reviewed fountain → should show rating, Instagram post link
4. Open `https://yvr-water-fountains.netlify.app/public_review_form.html`
5. Should show the simplified form with one rating row

**Step 4: Clean up the `src/` directory**

After confirming everything works, `src/` should be empty (api.js and ui.js were moved). If any other files remain, decide whether to move or delete them.

```bash
ls src/
# If empty: rmdir src/ && git add -A src/ && git commit -m "chore: remove empty src/ directory"
```

---

## Summary of all changes

| File | Change |
|------|--------|
| `supabase/migrations/20260302_drop_sub_ratings.sql` | New: migration to drop 5 sub-rating columns |
| `src/api.js` → `docs/js/api.js` | Moved + removed sub-rating cols from fetchReviewsByStatus |
| `src/ui.js` → `docs/js/ui.js` | Moved (no content changes) |
| `docs/map.html` | Added Supabase/api/fountain-data script tags, updated og:url |
| `docs/js/map.js` | Use `FountainData.fetchGeoData()`, remove `loadFountainData()` |
| `docs/config.js` | Hardcoded production Supabase URL + anon key as defaults |
| `docs/admin_review_form.html` | Removed 5 sub-rating input fields |
| `docs/js/admin-review-form.js` | Removed sub-rating collection, validation, and payload fields |
| `docs/public_review_form.html` | Removed 5 sub-rating radio groups |
| `docs/js/public-review-form.js` | Removed sub-rating collection and payload fields |
| `docs/js/moderation-dashboard.js` | Simplified review card to show single rating |
| `docs/link-instagram.html` | Updated api.js/ui.js paths |
| `docs/moderation_dashboard.html` | Updated api.js/ui.js paths |
| `docs/data/fountains_processed.geojson` | Regenerated with review data from Supabase |

## What's NOT in scope (deferred to later phases)

- Netlify functions (`submit-review.js`, `manage-rating.js`) — Phase 2
- Smart moderation / auto-screening — Phase 2
- Email notifications — Phase 2
- Instagram Graph API polling — Phase 3
- Map marker coloring by review status — Phase 4
- Admin password verification rework — Phase 4
- Removing `sources` or `admins` tables — deferred until replacement auth is designed
