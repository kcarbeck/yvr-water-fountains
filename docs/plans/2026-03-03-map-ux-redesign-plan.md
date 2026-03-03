# Map & UX Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Retheme map.html with y2k-inspired aesthetic, improve map dot UX, redesign popups/bottom sheet, show Instagram captions, and create a shared theme CSS file.

**Architecture:** Create a shared `docs/css/theme.css` with CSS custom properties and reusable classes. Modify `docs/map.html` to import it and use the new markup. Modify `docs/js/map.js` to produce the new popup/bottom-sheet HTML and use zoom-scaled dot sizing. No new JS files, no build step changes, no backend changes.

**Tech Stack:** Vanilla CSS (custom properties), Google Fonts (Bungee Shade, Quicksand, Fredoka One), Leaflet.js (existing), no new dependencies.

**Design doc:** `docs/plans/2026-03-03-map-ux-redesign-design.md`
**Visual preview:** `docs/preview_theme.html` (delete after implementation)

---

### Context for All Tasks

**Project structure:** All served files live under `docs/`. No bundler, no build step. Pages load scripts in order: Supabase CDN → env.local.js → config.js → api.js → ui.js → fountain-data.js → page JS. CSS is currently inline in each HTML file's `<style>` block.

**Color palette:**
- Primary (neon lime): `#c8ff00`
- Secondary (hot pink): `#ff69b4`
- Tertiary (sky blue): `#7eb6ff`
- Accent (lavender): `#c5a3ff`
- Dark (navy): `#1a1a2e`
- Light (ghost lavender): `#f5f0ff`

**Logo:** `docs/images/logo.png` (already uploaded by user)

**Key data fields available in fountain properties** (from `docs/js/fountain-data.js:108-148`):
- `caption` = `latest_review_text || latest_review_instagram_caption`
- `instagram_posts` = array with `{ url, date_posted, rating, caption, photo_url }`
- `admin_review_count`, `rating_count` — used for dot color logic
- `avg_rating`, `rating`, `latest_reviewer` — for display

---

### Task 1: Create shared theme CSS file

**Files:**
- Create: `docs/css/theme.css`

**Step 1: Create the `docs/css/` directory**

Run: `mkdir -p docs/css`

**Step 2: Create `docs/css/theme.css`**

Write the following file. This contains all CSS custom properties, Google Fonts imports, and reusable component classes that `map.html` will use. Future pages can import this too.

```css
/* ── YVR Water Fountains Theme ── */
/* Y2K-inspired palette + shared components */

@import url('https://fonts.googleapis.com/css2?family=Bungee+Shade&family=Fredoka+One&family=Quicksand:wght@500;600&display=swap');

:root {
  --color-primary: #c8ff00;
  --color-secondary: #ff69b4;
  --color-tertiary: #7eb6ff;
  --color-accent: #c5a3ff;
  --color-dark: #1a1a2e;
  --color-light: #f5f0ff;
  --color-info-bg: #fafbff;

  --font-display: 'Bungee Shade', cursive;
  --font-heading: 'Fredoka One', cursive;
  --font-subtitle: 'Quicksand', sans-serif;
  --font-body: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

/* ── Rating badge ── */
.rating-badge {
  display: inline-block;
  background: var(--color-primary);
  color: var(--color-dark);
  padding: 0.15rem 0.5rem;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 700;
}

/* ── Info section (lavender bg + left border) ── */
.info-section {
  background: var(--color-info-bg);
  border-radius: 10px;
  padding: 10px 12px;
  margin-bottom: 10px;
  border-left: 3px solid var(--color-accent);
}

/* ── Caption box ── */
.caption-box {
  font-size: 0.8rem;
  color: #555;
  font-style: italic;
  line-height: 1.4;
  padding: 8px 10px;
  background: var(--color-light);
  border-radius: 8px;
  max-height: 80px;
  overflow-y: auto;
  margin-top: 0.5rem;
}

/* ── Instagram link ── */
.ig-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--color-secondary);
  text-decoration: none;
  font-size: 0.85rem;
  font-weight: 600;
  margin-top: 0.5rem;
}

.ig-link:hover {
  text-decoration: underline;
}

/* ── CTA button ── */
.cta-btn {
  display: block;
  text-align: center;
  margin-top: 0.75rem;
  padding: 0.5rem;
  background: var(--color-primary);
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-dark);
  text-decoration: none;
}

.cta-btn:hover {
  opacity: 0.9;
}
```

**Step 3: Commit**

```bash
git add docs/css/theme.css
git commit -m "feat: add shared theme CSS with y2k color palette and reusable classes"
```

---

### Task 2: Retheme map.html — header, footer, favicon, fonts

**Files:**
- Modify: `docs/map.html`
- Reference: `docs/css/theme.css`, `docs/images/logo.png`

This task replaces the entire `<style>` block and HTML structure in `map.html` with the new themed version. It's the largest single task. The map JS behavior is unchanged — only the HTML shell and CSS change.

**Step 1: Add theme CSS link and favicon to `<head>`**

In `docs/map.html`, inside `<head>`, after the Leaflet CSS link (line 22), add:

```html
<link rel="stylesheet" href="css/theme.css">
<link rel="icon" type="image/png" href="images/logo.png">
```

Remove the old emoji favicon (line 11):
```html
<link rel="icon" href="data:image/svg+xml,...">
```

**Step 2: Replace the entire inline `<style>` block**

Replace everything between `<style>` and `</style>` (lines 23-631) with the new themed CSS. The new CSS must include:

- **Header styles:** neon lime bg, Bungee Shade h1, Quicksand tagline, dark nav pills, outlined `@yvrwaterfountains` link. No admin link in header.
- **Map:** `#map { height: calc(100vh - 120px); }` (smaller header = more map space)
- **Popup styles:** white card, colored top border (via `data-review-type` or class), Fredoka One title, info-section, caption-box, ig-link, rating-badge — all using `var()` references to theme.css custom properties.
- **Bottom sheet styles:** color bar at top, photo next to title, sheet-details, caption, action buttons.
- **Footer styles:** dark bg, neon lime links, dimmed admin link.
- **Responsive breakpoints:** maintain existing tablet (1024), mobile (768), small mobile (480) breakpoints but with the new compact header.
- **Leaflet popup override:** `.leaflet-popup-content-wrapper { border-radius: 14px; box-shadow: 0 4px 16px rgba(0,0,0,0.12); } .leaflet-popup-content { margin: 0; padding: 0; }`

Key CSS rules to include (full list — copy these exactly):

```css
body {
  margin: 0;
  font-family: var(--font-body);
  color: var(--color-dark);
}

/* ── Header ── */
.header {
  background: var(--color-primary);
  padding: 0.75rem 1.25rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.header-logo {
  width: 44px;
  height: 44px;
  border-radius: 8px;
  object-fit: cover;
}

.header h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.4rem;
  color: var(--color-dark);
  text-transform: uppercase;
  line-height: 1.1;
}

.header .tagline {
  font-family: var(--font-subtitle);
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-dark);
  opacity: 0.6;
  letter-spacing: 0.03em;
}

.nav-pills {
  display: flex;
  gap: 0.4rem;
  flex-wrap: wrap;
}

.nav-pill {
  background: var(--color-dark);
  color: var(--color-primary);
  padding: 0.4rem 0.9rem;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 600;
  text-decoration: none;
  transition: all 0.2s;
  border: 2px solid var(--color-dark);
}

.nav-pill:hover {
  background: transparent;
  color: var(--color-dark);
}

.nav-pill.outline {
  background: transparent;
  color: var(--color-dark);
  border-color: var(--color-dark);
}

.nav-pill.outline:hover {
  background: var(--color-dark);
  color: var(--color-primary);
}

/* ── Map ── */
#map {
  height: calc(100vh - 120px);
}

/* ── Leaflet popup override ── */
.leaflet-popup-content-wrapper {
  border-radius: 14px;
  box-shadow: 0 4px 16px rgba(0,0,0,0.12);
  padding: 0;
}

.leaflet-popup-content {
  margin: 0;
  font-family: var(--font-body);
}

/* ── Popup card ── */
.popup-content {
  max-width: 300px;
  padding: 16px;
  border-top: 4px solid var(--color-tertiary);
}

.popup-content.reviewed {
  border-top-color: var(--color-primary);
}

.popup-content.community-reviewed {
  border-top-color: var(--color-secondary);
}

.popup-title {
  font-family: var(--font-heading);
  font-size: 1.05rem;
  margin-bottom: 0.6rem;
}

.popup-title-link {
  color: var(--color-dark);
  text-decoration: none;
}

.popup-title-link:hover {
  color: var(--color-secondary);
}

.popup-info {
  display: flex;
  justify-content: space-between;
  padding: 0.3rem 0;
  font-size: 0.82rem;
  border-bottom: 1px solid #f0edf5;
}

.popup-info:last-of-type {
  border-bottom: none;
}

.popup-label {
  color: #888;
  font-weight: 500;
}

.popup-value {
  color: var(--color-dark);
  font-weight: 600;
}

.popup-clickable {
  color: var(--color-secondary);
  cursor: pointer;
  text-decoration: none;
}

.popup-clickable:hover {
  text-decoration: underline;
}

/* ── Bottom sheet ── */
.bottom-sheet {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: white;
  border-radius: 20px 20px 0 0;
  box-shadow: 0 -4px 20px rgba(0,0,0,0.15);
  transform: translateY(100%);
  transition: transform 0.3s ease-out;
  z-index: 2000;
  max-height: 80vh;
  overflow-y: auto;
  overflow-x: hidden;
}

.bottom-sheet.active {
  transform: translateY(0);
}

.sheet-color-bar {
  height: 4px;
  background: var(--color-tertiary);
}

.sheet-color-bar.reviewed {
  background: var(--color-primary);
}

.sheet-color-bar.community-reviewed {
  background: var(--color-secondary);
}

.bottom-sheet-handle {
  width: 40px;
  height: 4px;
  background: #ddd;
  border-radius: 2px;
  margin: 12px auto;
}

.bottom-sheet-content {
  padding: 0 20px 20px;
}

.sheet-header {
  display: flex;
  gap: 12px;
  margin-bottom: 1rem;
}

.sheet-photo {
  width: 70px;
  height: 70px;
  border-radius: 10px;
  object-fit: cover;
  flex-shrink: 0;
}

.sheet-header-text {
  flex: 1;
  min-width: 0;
}

.bottom-sheet-title {
  font-family: var(--font-heading);
  font-size: 1.1rem;
  color: var(--color-dark);
  margin-bottom: 0.2rem;
}

.sheet-subtitle {
  font-size: 0.8rem;
  color: #888;
}

.sheet-details {
  background: var(--color-info-bg);
  border-radius: 10px;
  padding: 12px;
  margin-bottom: 12px;
  border-left: 3px solid var(--color-accent);
}

.sheet-row {
  display: flex;
  justify-content: space-between;
  padding: 0.3rem 0;
  font-size: 0.85rem;
  border-bottom: 1px solid #f0edf5;
}

.sheet-row:last-child {
  border-bottom: none;
}

.bottom-sheet-label {
  color: #888;
  font-weight: 500;
}

.bottom-sheet-value {
  color: var(--color-dark);
  font-weight: 600;
}

.sheet-caption {
  font-size: 0.8rem;
  color: #555;
  font-style: italic;
  line-height: 1.4;
  padding: 10px 12px;
  background: var(--color-light);
  border-radius: 8px;
  margin-bottom: 12px;
  max-height: 100px;
  overflow-y: auto;
}

.sheet-actions {
  display: flex;
  gap: 8px;
}

.sheet-action-btn {
  flex: 1;
  text-align: center;
  padding: 0.5rem;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 600;
  text-decoration: none;
}

.sheet-action-btn.primary {
  background: var(--color-secondary);
  color: #fff;
}

.sheet-action-btn.secondary {
  background: var(--color-light);
  color: var(--color-dark);
}

.bottom-sheet-close {
  position: absolute;
  top: 10px;
  right: 16px;
  background: none;
  border: none;
  font-size: 1.5rem;
  color: #999;
  cursor: pointer;
  width: 30px;
  height: 30px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5);
  z-index: 1999;
  opacity: 0;
  visibility: hidden;
  transition: opacity 0.3s ease-out;
}

.overlay.active {
  opacity: 1;
  visibility: visible;
}

/* ── Footer ── */
.footer {
  background: var(--color-dark);
  color: var(--color-accent);
  padding: 1rem 1.5rem;
  text-align: center;
  font-size: 0.85rem;
}

.footer a {
  color: var(--color-primary);
  text-decoration: none;
  font-weight: 600;
}

.footer a:hover {
  color: var(--color-secondary);
}

.footer-links {
  display: flex;
  justify-content: center;
  gap: 1.5rem;
  margin-bottom: 0.5rem;
  flex-wrap: wrap;
}

.footer-divider {
  border: none;
  border-top: 1px solid rgba(197,163,255,0.2);
  margin: 0.5rem 0;
}

.footer-credit {
  font-size: 0.75rem;
  color: rgba(197,163,255,0.6);
}

.footer .admin-link {
  color: rgba(197,163,255,0.4);
  font-weight: 400;
}

/* ── Mobile: hide popups, show bottom sheet ── */
@media (max-width: 768px) {
  .header h1 { font-size: 1.1rem; }
  .header .tagline { font-size: 0.7rem; }
  .header-logo { width: 36px; height: 36px; }
  .nav-pill { font-size: 0.75rem; padding: 0.35rem 0.7rem; }
  #map { height: calc(100vh - 100px); }
  .leaflet-popup { display: none !important; }
  .bottom-sheet { max-height: 85vh; }
  .bottom-sheet-content { padding: 0 15px 15px; }
  .sheet-photo { width: 60px; height: 60px; }
  .footer { padding: 0.75rem 1rem; }
  .footer-links { gap: 1rem; }
}

@media (max-width: 480px) {
  .header { padding: 0.5rem 0.75rem; }
  .header h1 { font-size: 0.95rem; }
  .nav-pill { font-size: 0.7rem; padding: 0.3rem 0.5rem; }
  #map { height: calc(100vh - 90px); }
}

@media (min-width: 1200px) {
  .header { padding: 0.75rem 2rem; }
  .popup-content { max-width: 340px; }
}
```

**Step 3: Replace the header HTML**

Replace the old header (lines 634-642 in current `map.html`) with:

```html
<div class="header">
  <div class="header-left">
    <img src="images/logo.png" alt="YVR Water Fountains" class="header-logo">
    <div>
      <h1>YVR Water Fountains</h1>
      <span class="tagline">where to hydrate in Vancouver</span>
    </div>
  </div>
  <div class="nav-pills">
    <a href="public_review_form.html" class="nav-pill">Submit Review</a>
    <a href="#" id="locate-me" class="nav-pill">My Location</a>
    <a href="https://www.instagram.com/yvrwaterfountains/" target="_blank" class="nav-pill outline">@yvrwaterfountains</a>
  </div>
</div>
```

Note: The admin access link (`id="admin-access"`) is removed from the header. It moves to the footer.

**Step 4: Replace the footer HTML**

Replace the old footer (lines 649-663) with:

```html
<div class="footer">
  <div class="footer-links">
    <a href="https://www.instagram.com/yvrwaterfountains/" target="_blank">@yvrwaterfountains</a>
    <a href="public_review_form.html">Submit a Review</a>
    <a href="https://github.com/kcarbeck/yvr-water-fountains" target="_blank">GitHub</a>
    <a href="#" id="admin-access" class="admin-link">Admin</a>
  </div>
  <hr class="footer-divider">
  <div class="footer-credit">
    Community-maintained fountain ratings across Vancouver & Burnaby
    <br>Built by <a href="https://github.com/kcarbeck" target="_blank">kcarbeck</a>
  </div>
</div>
```

**Step 5: Update the bottom sheet HTML**

Add a color bar div inside the bottom sheet. Replace lines 667-673:

```html
<div class="overlay" id="overlay"></div>
<div class="bottom-sheet" id="bottom-sheet">
  <div class="sheet-color-bar" id="sheet-color-bar"></div>
  <div class="bottom-sheet-handle"></div>
  <button class="bottom-sheet-close" id="bottom-sheet-close">&times;</button>
  <div class="bottom-sheet-content" id="bottom-sheet-content"></div>
</div>
```

**Step 6: Verify in browser**

Run: `cd docs && python3 -m http.server 8000`
Visit: `http://localhost:8000/map.html`
Expected: New header with neon lime bg, logo, Bungee Shade title, nav pills. Footer with dark bg and links. Map fills most of viewport. Admin link is in footer only.

**Step 7: Commit**

```bash
git add docs/map.html
git commit -m "feat: retheme map.html with y2k header, footer, favicon, and shared CSS"
```

---

### Task 3: Update map marker styles (colors, outlines, zoom scaling)

**Files:**
- Modify: `docs/js/map.js:207-231` (markerStyle function)
- Modify: `docs/js/map.js:236-244` (placeFountainsOnMap function)

**Step 1: Replace `markerStyle()` function**

Replace lines 207-231 in `docs/js/map.js` with a new version that uses the theme colors and a fixed base radius (dots will be scaled in the next step):

```javascript
function markerStyle(props) {
  const adminCount = props.admin_review_count || 0;
  const totalCount = props.rating_count || 0;
  let color;

  if (adminCount > 0) {
    color = '#c8ff00';
  } else if (totalCount > 0) {
    color = '#ff69b4';
  } else {
    color = '#7eb6ff';
  }

  return {
    radius: 6,
    color: '#1a1a2e',
    fillColor: color,
    fillOpacity: 0.85,
    weight: 1.5
  };
}
```

**Step 2: Add zoom-based radius scaling**

After `placeFountainsOnMap()` (line ~244), add a `registerZoomScaling()` function and call it. This adjusts dot radii when the user zooms.

Add this new function right after `placeFountainsOnMap`:

```javascript
function registerZoomScaling(geoLayer) {
  function updateRadii() {
    const zoom = state.map.getZoom();
    const baseRadius = Math.max(3, Math.min(10, zoom - 7));
    geoLayer.eachLayer(function (layer) {
      if (typeof layer.setRadius === 'function') {
        layer.setRadius(baseRadius);
      }
    });
  }

  state.map.on('zoomend', updateRadii);
  updateRadii();
}
```

Then modify `placeFountainsOnMap` to capture the layer and call the scaler:

```javascript
function placeFountainsOnMap(geojson) {
  const geoLayer = L.geoJSON(geojson, {
    pointToLayer: (feature, latlng) => {
      const props = feature.properties || {};
      const style = markerStyle(props);
      return L.circleMarker(latlng, style);
    },
    onEachFeature: (feature, layer) => attachFountainBehavior(feature, layer)
  }).addTo(state.map);

  registerZoomScaling(geoLayer);
}
```

**Step 3: Verify in browser**

Visit `http://localhost:8000/map.html`, zoom in and out.
Expected: Dots are neon lime (reviewed), sky blue (unreviewed) with dark outlines. They grow larger when zoomed in, smaller when zoomed out.

**Step 4: Commit**

```bash
git add docs/js/map.js
git commit -m "feat: update map markers to themed colors with zoom-responsive sizing"
```

---

### Task 4: Redesign desktop popup markup

**Files:**
- Modify: `docs/js/map.js:389-433` (buildPopupContent function)

**Step 1: Replace `buildPopupContent()`**

Replace lines 389-433 with a new version that uses the themed CSS classes (info-section, rating-badge, caption-box, ig-link) and adds the Instagram caption text:

```javascript
function buildPopupContent(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
  const isReviewed = (fountain.admin_review_count || 0) > 0;
  const isCommunity = !isReviewed && (fountain.rating_count || 0) > 0;
  const typeClass = isReviewed ? ' reviewed' : isCommunity ? ' community-reviewed' : '';

  let html = '<div class="popup-content' + typeClass + '">';

  // Title with optional photo
  if (latestPhotoUrl) {
    html += '<img src="' + latestPhotoUrl + '" alt="Photo" style="width:80px;height:80px;border-radius:10px;float:right;margin-left:10px;object-fit:cover;" onerror="this.style.display=\'none\'">';
  }
  html += '<div class="popup-title">';
  html += '<a href="#" class="popup-title-link" onclick="showFountainDetails(\'' + (fountain.id || '') + '\')">' + (fountain.name || 'Unnamed Fountain') + '</a>';
  html += '</div>';

  // Info section
  html += '<div class="info-section">';
  html += buildInfoRow('popup', 'Location', fountain.location || fountain.address || '\u2014');
  html += buildInfoRow('popup', 'Neighbourhood', fountain.neighborhood || '\u2014');

  if (fountain.avg_rating) {
    const count = fountain.rating_count || 0;
    const avg = Number.parseFloat(fountain.avg_rating).toFixed(1);
    html += buildInfoRow('popup', 'Rating', '<span class="rating-badge">' + avg + '/10</span> (' + count + ' review' + (count !== 1 ? 's' : '') + ')');
  }

  html += buildInfoRow('popup', 'Operational', formatOperational(fountain.currently_operational));
  html += buildInfoRow('popup', 'Pet Friendly', formatPetFriendly(fountain.pet_friendly));
  html += '</div>';

  // Caption
  if (fountain.caption) {
    const truncated = fountain.caption.length > 200 ? fountain.caption.slice(0, 200) + '...' : fountain.caption;
    html += '<div class="caption-box">' + truncated + '</div>';
  }

  // Instagram link
  if (latestInstagramPost) {
    html += '<a href="' + latestInstagramPost.url + '" target="_blank" class="ig-link">@yvrwaterfountains post \u2192</a>';
  }

  // CTA for unreviewed
  if (!fountain.rating) {
    html += '<a href="public_review_form.html" class="cta-btn">Be the first to review!</a>';
  }

  html += '</div>';
  return html;
}
```

**Step 2: Update `buildInfoRow()` for new flat layout**

Replace lines 512-520 (`buildInfoRow` function) with a version that works for both contexts but uses the new flat style:

```javascript
function buildInfoRow(context, label, value) {
  const baseClass = context === 'popup' ? 'popup' : 'bottom-sheet';
  return '<div class="' + baseClass + '-info"><span class="' + baseClass + '-label">' + label + '</span><span class="' + baseClass + '-value">' + value + '</span></div>';
}
```

(This is functionally identical to the current version — just keeping it in case the class names need to stay consistent for the sheet.)

**Step 3: Verify in browser (desktop)**

Visit `http://localhost:8000/map.html` on desktop, click a reviewed fountain.
Expected: Popup has colored top border (lime for admin-reviewed), Fredoka One title, lavender info section, caption text in italic box, pink Instagram link.

Click an unreviewed fountain.
Expected: Blue top border, no caption, "Be the first to review!" CTA button.

**Step 4: Commit**

```bash
git add docs/js/map.js
git commit -m "feat: redesign desktop popup with themed layout, caption text, and CTA"
```

---

### Task 5: Redesign mobile bottom sheet markup

**Files:**
- Modify: `docs/js/map.js:438-488` (buildBottomSheetContent function)
- Modify: `docs/js/map.js:525-534` (showBottomSheet function)

**Step 1: Replace `buildBottomSheetContent()`**

Replace lines 438-488 with:

```javascript
function buildBottomSheetContent(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
  let html = '';

  // Header with optional photo
  if (latestPhotoUrl) {
    html += '<div class="sheet-header">';
    html += '<img src="' + latestPhotoUrl + '" alt="Photo" class="sheet-photo" onerror="this.style.display=\'none\'">';
    html += '<div class="sheet-header-text">';
  } else {
    html += '<div style="margin-bottom:1rem;">';
  }

  html += '<div class="bottom-sheet-title">';
  html += '<a href="#" class="popup-title-link" onclick="showFountainDetails(\'' + (fountain.id || '') + '\')">' + (fountain.name || 'Unnamed Fountain') + '</a>';
  html += '</div>';
  html += '<div class="sheet-subtitle">' + (fountain.neighborhood || '') + (fountain.location ? ' \u00B7 ' + fountain.location : '') + '</div>';

  if (fountain.avg_rating) {
    html += '<span class="rating-badge" style="margin-top:0.25rem;display:inline-block;">' + Number.parseFloat(fountain.avg_rating).toFixed(1) + '/10</span>';
  }

  if (latestPhotoUrl) {
    html += '</div></div>';
  } else {
    html += '</div>';
  }

  // Details section
  html += '<div class="sheet-details">';
  html += buildInfoRow('bottom-sheet', 'Operational', formatOperational(fountain.currently_operational));
  html += buildInfoRow('bottom-sheet', 'Pet Friendly', formatPetFriendly(fountain.pet_friendly));

  if (fountain.rating) {
    const reviewer = fountain.latest_reviewer || 'Anonymous';
    html += buildInfoRow('bottom-sheet', 'Reviewed by', reviewer);
  }

  if (fountain.wheelchair_accessible && fountain.wheelchair_accessible !== 'unknown') {
    html += buildInfoRow('bottom-sheet', 'Wheelchair', fountain.wheelchair_accessible);
  }
  html += '</div>';

  // Caption
  if (fountain.caption) {
    html += '<div class="sheet-caption">' + fountain.caption + '</div>';
  }

  // Action buttons
  html += '<div class="sheet-actions">';
  if (latestInstagramPost) {
    html += '<a href="' + latestInstagramPost.url + '" target="_blank" class="sheet-action-btn primary">View on Instagram</a>';
  }
  if (fountain.rating) {
    html += '<a href="public_review_form.html" class="sheet-action-btn secondary">Submit Review</a>';
  } else {
    html += '<a href="public_review_form.html" class="sheet-action-btn primary" style="background:var(--color-primary);color:var(--color-dark);">Be the first to review!</a>';
  }
  html += '</div>';

  return html;
}
```

**Step 2: Update `showBottomSheet()` to set the color bar**

Replace lines 525-534 with:

```javascript
function showBottomSheet(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
  if (!dom.bottomSheet || !dom.bottomSheetContent || !dom.overlay) {
    return;
  }

  state.currentFountain = fountain;

  // Set color bar based on review type
  const colorBar = document.getElementById('sheet-color-bar');
  if (colorBar) {
    colorBar.className = 'sheet-color-bar';
    if ((fountain.admin_review_count || 0) > 0) {
      colorBar.classList.add('reviewed');
    } else if ((fountain.rating_count || 0) > 0) {
      colorBar.classList.add('community-reviewed');
    }
  }

  dom.bottomSheetContent.innerHTML = buildBottomSheetContent(fountain, latestInstagramPost, latestPhotoUrl, adminReview);
  dom.bottomSheet.classList.add('active');
  dom.overlay.classList.add('active');
}
```

**Step 3: Verify in browser (mobile)**

Open Chrome DevTools, toggle device toolbar (Ctrl+Shift+M), select a mobile device.
Visit `http://localhost:8000/map.html`, tap a reviewed fountain.
Expected: Bottom sheet slides up with lime color bar, fountain name in Fredoka One, subtitle with neighbourhood, rating badge, lavender details section, caption text, action buttons.

Tap an unreviewed fountain.
Expected: Blue color bar, no photo, no caption, "Be the first to review!" button.

**Step 4: Commit**

```bash
git add docs/js/map.js
git commit -m "feat: redesign mobile bottom sheet with themed layout, photo, caption, and actions"
```

---

### Task 6: Clean up and final verification

**Files:**
- Delete: `docs/preview_theme.html`
- Verify: all pages still load

**Step 1: Delete the preview file**

```bash
rm docs/preview_theme.html
```

**Step 2: Full verification checklist**

Run: `cd docs && python3 -m http.server 8000`

Test each of these:

1. `http://localhost:8000/map.html` — desktop: header shows logo + Bungee Shade title + nav pills + @yvrwaterfountains link. Footer has dark bg with GitHub + Admin links. Map renders with themed dot colors.
2. Click a reviewed fountain — popup has lime top border, Fredoka One name, lavender info section, caption text, pink IG link.
3. Click an unreviewed fountain — popup has blue top border, "Be the first to review!" CTA.
4. Resize to mobile — header compacts, popups hidden, bottom sheet works with color bar + photo + caption + action buttons.
5. Zoom in/out — dots scale with zoom level.
6. `http://localhost:8000/admin_review_form.html` — still works (unchanged).
7. `http://localhost:8000/moderation_dashboard.html` — still works (unchanged).
8. `http://localhost:8000/backfill_instagram.html` — still works (unchanged).

**Step 3: Commit cleanup**

```bash
git add -A
git commit -m "chore: delete theme preview file after implementation"
```

---

### Summary of all commits

1. `feat: add shared theme CSS with y2k color palette and reusable classes`
2. `feat: retheme map.html with y2k header, footer, favicon, and shared CSS`
3. `feat: update map markers to themed colors with zoom-responsive sizing`
4. `feat: redesign desktop popup with themed layout, caption text, and CTA`
5. `feat: redesign mobile bottom sheet with themed layout, photo, caption, and actions`
6. `chore: delete theme preview file after implementation`
