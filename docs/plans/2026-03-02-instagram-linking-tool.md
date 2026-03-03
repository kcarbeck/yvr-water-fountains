# Instagram Post Linking Tool — Implementation Plan

> **Status:** ✅ COMPLETED (March 2, 2026)

**Goal:** Build a browser-based tool that lets the admin bulk-link Instagram export posts to fountains on the map, with fuzzy-matching, rating extraction, and the ability to create new fountains.

**Outcome:** All 4 tasks completed. 42 Instagram reels linked to fountains. New Supabase project created (old one was paused >90 days). 428 fountains imported. 2 new fountains created during backfill. Hillcrest and Cambie data fixes applied.

**Architecture:** Standalone HTML page (`docs/link-instagram.html`) using the same vanilla JS + Supabase + Leaflet stack as the rest of the site. Reuses `config.js`, `src/api.js`, `src/ui.js`, and `docs/js/fountain-data.js`. No build step, no new dependencies. Admin auth required (same Supabase sign-in as `admin_review_form.html`).

**Tech Stack:** Vanilla JS (IIFE modules), Leaflet maps, Supabase JS SDK (CDN), Bootstrap 5 (CDN)

**Note on testing:** This project has no test runner configured. Each task includes manual verification steps instead. Test in browser with dev tools open.

---

## Task 1: Create the HTML shell and load dependencies

**Files:**
- Create: `docs/link-instagram.html`

**Step 1: Create the HTML page with layout and dependencies**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YVR Water Fountains - Link Instagram Posts</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px 0;
        }
        .main-card {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow: hidden;
            max-width: 1400px;
            margin: 0 auto;
        }
        .header {
            background: linear-gradient(45deg, #2196F3, #21CBF3);
            color: white;
            padding: 20px 30px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 { margin: 0; font-size: 1.5rem; font-weight: 300; }
        .progress-badge {
            background: rgba(255,255,255,0.2);
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 0.9rem;
        }
        .content-wrapper {
            display: grid;
            grid-template-columns: 1fr 1fr;
            min-height: 70vh;
        }
        .post-section { padding: 24px; overflow-y: auto; max-height: 80vh; }
        .map-section { position: relative; }
        #map { height: 100%; min-height: 500px; width: 100%; }
        .search-overlay {
            position: absolute; top: 10px; left: 10px; right: 10px;
            z-index: 1000; background: white; border-radius: 8px;
            padding: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }
        .post-card {
            border: 2px solid #e0e0e0;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 16px;
        }
        .post-card .caption {
            font-size: 0.95rem;
            line-height: 1.5;
            white-space: pre-wrap;
            max-height: 200px;
            overflow-y: auto;
        }
        .post-card .meta { color: #666; font-size: 0.85rem; margin-top: 8px; }
        .match-info {
            background: #f0f9ff;
            border: 2px solid #2196F3;
            border-radius: 10px;
            padding: 16px;
            margin: 12px 0;
        }
        .match-info.confirmed {
            border-color: #198754;
            background: #f0fdf4;
        }
        .rating-input-lg {
            width: 80px; height: 80px;
            border: 3px solid #e0e0e0; border-radius: 50%;
            font-size: 24px; font-weight: bold; text-align: center;
        }
        .rating-input-lg:focus {
            border-color: #2196F3;
            box-shadow: 0 0 0 3px rgba(33, 150, 243, 0.1);
        }
        .drop-zone {
            border: 3px dashed #ccc; border-radius: 15px;
            padding: 60px 40px; text-align: center; cursor: pointer;
            transition: all 0.3s;
        }
        .drop-zone:hover, .drop-zone.dragover {
            border-color: #2196F3; background: #f0f9ff;
        }
        .fountain-item {
            padding: 8px 12px; cursor: pointer; border-radius: 6px;
            border: 1px solid transparent;
        }
        .fountain-item:hover { background: #f0f9ff; border-color: #2196F3; }
        .fountain-item.selected { background: #e8f5e9; border-color: #198754; }
        .btn-action {
            border-radius: 10px; padding: 12px 24px;
            font-size: 16px; font-weight: 600;
        }
        #newFountainPanel {
            background: #fffbeb; border: 2px solid #f59e0b;
            border-radius: 10px; padding: 16px; margin: 12px 0;
        }
        .auth-section { padding: 20px 30px; background: #fff3cd; }
        @media (max-width: 768px) {
            .content-wrapper { grid-template-columns: 1fr; }
            .map-section { height: 350px; }
        }
    </style>
</head>
<body>
    <div class="main-card">
        <!-- Auth bar -->
        <div id="authSection" class="auth-section">
            <div class="d-flex align-items-center gap-3">
                <span id="authStatus">Sign in to start linking posts.</span>
                <input type="email" id="authEmail" class="form-control form-control-sm" style="max-width:200px" placeholder="Email">
                <input type="password" id="authPassword" class="form-control form-control-sm" style="max-width:200px" placeholder="Password">
                <button id="authSignIn" class="btn btn-sm btn-primary">Sign In</button>
                <button id="authSignOut" class="btn btn-sm btn-outline-secondary" style="display:none">Sign Out</button>
            </div>
        </div>

        <div class="header">
            <h1><i class="fab fa-instagram"></i> Link Instagram Posts</h1>
            <div id="progressBadge" class="progress-badge" style="display:none">
                <span id="progressText">0 / 0 linked</span>
            </div>
        </div>

        <div id="mainContent" style="display:none">
            <!-- Upload phase -->
            <div id="uploadPhase" class="p-4">
                <div class="drop-zone" id="dropZone">
                    <i class="fas fa-cloud-upload-alt fa-3x mb-3" style="color:#aaa"></i>
                    <h4>Drop your Instagram export JSON here</h4>
                    <p class="text-muted">Or click to browse. Look for <code>content/posts_1.json</code> in your export ZIP.</p>
                    <input type="file" id="fileInput" accept=".json" style="display:none">
                </div>
            </div>

            <!-- Linking phase -->
            <div id="linkingPhase" style="display:none">
                <div class="content-wrapper">
                    <div class="post-section">
                        <div id="postCard" class="post-card"></div>
                        <div id="matchInfo" class="match-info"></div>
                        <div id="newFountainPanel" style="display:none">
                            <h6><i class="fas fa-plus-circle"></i> Add New Fountain</h6>
                            <div class="mb-2">
                                <input type="text" id="newFountainName" class="form-control form-control-sm" placeholder="Fountain name">
                            </div>
                            <div class="mb-2">
                                <small class="text-muted">Tap the map to set location. <span id="newFountainCoords"></span></small>
                            </div>
                            <button id="saveNewFountain" class="btn btn-sm btn-warning">Create Fountain</button>
                            <button id="cancelNewFountain" class="btn btn-sm btn-outline-secondary">Cancel</button>
                        </div>
                        <div class="d-flex align-items-center gap-3 mt-3">
                            <div class="text-center">
                                <label class="form-label mb-1" style="font-size:0.8rem">Rating</label>
                                <input type="number" id="ratingInput" class="rating-input-lg" min="1" max="10" step="0.5">
                            </div>
                            <div class="flex-grow-1 d-flex flex-column gap-2">
                                <button id="confirmBtn" class="btn btn-success btn-action" disabled>
                                    <i class="fas fa-check"></i> Confirm & Next
                                </button>
                                <div class="d-flex gap-2">
                                    <button id="skipBtn" class="btn btn-outline-secondary btn-sm flex-grow-1">Skip</button>
                                    <button id="addFountainBtn" class="btn btn-outline-warning btn-sm flex-grow-1">
                                        <i class="fas fa-plus"></i> New Fountain
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="map-section">
                        <div class="search-overlay">
                            <input type="text" id="fountainSearch" class="form-control form-control-sm" placeholder="Search fountains by name...">
                        </div>
                        <div id="map"></div>
                    </div>
                </div>
            </div>

            <!-- Done phase -->
            <div id="donePhase" style="display:none" class="p-5 text-center">
                <i class="fas fa-check-circle fa-4x text-success mb-3"></i>
                <h3>All done!</h3>
                <p id="doneSummary" class="text-muted"></p>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.43.1/dist/umd/supabase.min.js"></script>
    <script src="config.js"></script>
    <script src="../src/api.js"></script>
    <script src="../src/ui.js"></script>
    <script src="js/fountain-data.js"></script>
    <script src="js/link-instagram.js"></script>
</body>
</html>
```

**Step 2: Verify the page loads**

Open `docs/link-instagram.html` in a browser. Confirm:
- Blue gradient header shows "Link Instagram Posts"
- Auth bar appears at top with sign-in fields
- Drop zone appears with upload prompt
- No console errors (all CDN scripts load)

**Step 3: Commit**

```bash
git add docs/link-instagram.html
git commit -m "feat: add HTML shell for instagram linking tool"
```

---

## Task 2: Build the core linking JS — auth, file loading, Instagram JSON parsing

**Files:**
- Create: `docs/js/link-instagram.js`

**Step 1: Write the module with auth, file loading, and Instagram export parsing**

Instagram data exports use a specific JSON structure. The file is typically found at `content/posts_1.json` inside the ZIP. Posts contain `media` arrays with `title` (caption) and `creation_timestamp` (Unix seconds). The post URL can be reconstructed if the export includes it, otherwise we store what we have.

```javascript
'use strict';

(function () {
  var config = window.APP_CONFIG || {};
  var api = window.AppApi || {};
  var ui = window.AppUI || {};

  var state = {
    supabaseClient: null,
    isAdmin: false,
    fountains: [],        // GeoJSON features
    fountainList: [],      // plain objects for search
    posts: [],             // parsed Instagram posts
    currentIndex: 0,
    linked: 0,
    skipped: 0,
    map: null,
    markers: [],
    markerById: new Map(),
    selectedFountain: null,
    selectedMarker: null,
    addingNewFountain: false,
    newFountainLatLng: null
  };

  document.addEventListener('DOMContentLoaded', init);

  function init() {
    setupAuth();
    setupFileUpload();
    setupActions();
  }

  // ── Auth ──────────────────────────────────────────

  function setupAuth() {
    var signInBtn = document.getElementById('authSignIn');
    var signOutBtn = document.getElementById('authSignOut');

    if (!api.hasCredentials || !api.hasCredentials()) {
      setAuthStatus('Supabase not configured. Check config.js.');
      return;
    }

    state.supabaseClient = api.getClient();
    if (!state.supabaseClient) {
      setAuthStatus('Supabase client failed to initialize.');
      return;
    }

    signInBtn.addEventListener('click', async function () {
      var email = document.getElementById('authEmail').value.trim();
      var password = document.getElementById('authPassword').value;
      if (!email || !password) return;
      try {
        var result = await state.supabaseClient.auth.signInWithPassword({ email: email, password: password });
        if (result.error) {
          setAuthStatus('Sign in failed: ' + result.error.message);
        }
      } catch (e) {
        setAuthStatus('Sign in error. Check console.');
        console.error(e);
      }
    });

    signOutBtn.addEventListener('click', function () {
      state.supabaseClient.auth.signOut();
    });

    state.supabaseClient.auth.onAuthStateChange(function (_event, session) {
      applySession(session);
    });

    state.supabaseClient.auth.getSession().then(function (result) {
      var session = result.data && result.data.session ? result.data.session : null;
      applySession(session);
    });
  }

  async function applySession(session) {
    var signInBtn = document.getElementById('authSignIn');
    var signOutBtn = document.getElementById('authSignOut');
    var emailInput = document.getElementById('authEmail');
    var passwordInput = document.getElementById('authPassword');
    var mainContent = document.getElementById('mainContent');

    state.isAdmin = false;

    if (!session) {
      setAuthStatus('Sign in to start linking posts.');
      signInBtn.style.display = '';
      signOutBtn.style.display = 'none';
      emailInput.style.display = '';
      passwordInput.style.display = '';
      mainContent.style.display = 'none';
      return;
    }

    // Check admin status
    try {
      var profile = await api.fetchAdminProfile(session.user.id, state.supabaseClient);
      if (!profile) {
        setAuthStatus('Signed in but not an admin. Ask the owner to add you.');
        mainContent.style.display = 'none';
        return;
      }
      state.isAdmin = true;
      setAuthStatus('Signed in as ' + escapeHtml(profile.display_name || session.user.email));
      signInBtn.style.display = 'none';
      signOutBtn.style.display = '';
      emailInput.style.display = 'none';
      passwordInput.style.display = 'none';
      mainContent.style.display = 'block';
    } catch (e) {
      setAuthStatus('Could not verify admin status.');
      console.error(e);
    }
  }

  function setAuthStatus(msg) {
    var el = document.getElementById('authStatus');
    if (el) el.textContent = msg;
  }

  // ── File Upload & Parsing ────────────────────────

  function setupFileUpload() {
    var dropZone = document.getElementById('dropZone');
    var fileInput = document.getElementById('fileInput');

    dropZone.addEventListener('click', function () { fileInput.click(); });
    dropZone.addEventListener('dragover', function (e) {
      e.preventDefault();
      dropZone.classList.add('dragover');
    });
    dropZone.addEventListener('dragleave', function () {
      dropZone.classList.remove('dragover');
    });
    dropZone.addEventListener('drop', function (e) {
      e.preventDefault();
      dropZone.classList.remove('dragover');
      if (e.dataTransfer.files.length) handleFile(e.dataTransfer.files[0]);
    });
    fileInput.addEventListener('change', function () {
      if (fileInput.files.length) handleFile(fileInput.files[0]);
    });
  }

  async function handleFile(file) {
    try {
      var text = await file.text();
      var json = JSON.parse(text);
      state.posts = parseInstagramExport(json);
      if (state.posts.length === 0) {
        ui.toast('No posts found in this file. Check the format.', 'warning');
        return;
      }
      ui.toast(state.posts.length + ' posts loaded.', 'success');
      await startLinking();
    } catch (e) {
      ui.toast('Failed to parse file: ' + e.message, 'error');
      console.error(e);
    }
  }

  /**
   * Parses Instagram data export JSON into a normalized array.
   *
   * Instagram exports vary in structure. Known formats:
   *
   * Format A (common): Array of objects with media arrays
   *   [{ "media": [{ "uri": "...", "creation_timestamp": 1684000000, "title": "caption" }] }]
   *
   * Format B: Object with an array under a key
   *   { "ig_media": [...] } or { "posts": [...] }
   *
   * Format C: Flat array of media objects
   *   [{ "uri": "...", "creation_timestamp": ..., "title": "..." }]
   */
  function parseInstagramExport(json) {
    var rawPosts = [];

    if (Array.isArray(json)) {
      // Format A or C
      json.forEach(function (item) {
        if (item.media && Array.isArray(item.media)) {
          // Format A: each item has a media array
          item.media.forEach(function (m) { rawPosts.push(m); });
        } else if (item.creation_timestamp || item.taken_at) {
          // Format C: flat array of media objects
          rawPosts.push(item);
        }
      });
    } else if (typeof json === 'object' && json !== null) {
      // Format B: look for a known key
      var candidates = ['ig_media', 'posts', 'media', 'photos_and_videos'];
      for (var i = 0; i < candidates.length; i++) {
        if (Array.isArray(json[candidates[i]])) {
          rawPosts = json[candidates[i]];
          break;
        }
      }
      // If still empty, try nested: content > posts
      if (rawPosts.length === 0 && json.content && Array.isArray(json.content)) {
        json.content.forEach(function (item) {
          if (item.media && Array.isArray(item.media)) {
            item.media.forEach(function (m) { rawPosts.push(m); });
          }
        });
      }
    }

    return rawPosts.map(function (post) {
      var caption = post.title || post.caption || post.text || '';
      if (typeof caption === 'object' && caption.text) caption = caption.text;

      var timestamp = post.creation_timestamp || post.taken_at || post.timestamp;
      var date = timestamp ? new Date(timestamp * 1000) : null;

      var uri = post.uri || post.media_url || post.url || '';
      var permalink = post.permalink || post.link || '';

      // Try to reconstruct Instagram URL from uri path if no permalink
      if (!permalink && uri) {
        // Export URIs are local paths like "media/posts/202305/photo.jpg" — no URL to extract
      }

      return {
        caption: caption,
        date: date,
        dateStr: date ? date.toISOString().split('T')[0] : null,
        mediaUri: uri,
        permalink: permalink,
        raw: post
      };
    }).filter(function (p) {
      // Filter out posts with no caption (likely stories or non-review posts)
      return p.caption && p.caption.trim().length > 0;
    }).sort(function (a, b) {
      // Oldest first
      if (!a.date) return 1;
      if (!b.date) return -1;
      return a.date - b.date;
    });
  }

  // ── Fuzzy Matching ───────────────────────────────

  /**
   * Scores each fountain against caption text.
   * Returns sorted array of { fountain, score } with best matches first.
   */
  function fuzzyMatchFountains(caption, fountainFeatures) {
    var words = caption.toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter(function (w) { return w.length > 2; });

    var uniqueWords = [];
    var seen = {};
    words.forEach(function (w) {
      if (!seen[w]) { seen[w] = true; uniqueWords.push(w); }
    });

    var scored = fountainFeatures.map(function (feature) {
      var props = feature.properties || {};
      var name = (props.name || '').toLowerCase();
      var neighbourhood = (props.neighborhood || '').toLowerCase();
      var location = (props.location || '').toLowerCase();
      var target = name + ' ' + neighbourhood + ' ' + location;

      var score = 0;
      uniqueWords.forEach(function (word) {
        if (target.includes(word)) {
          // Bonus for name match vs neighbourhood match
          if (name.includes(word)) score += 3;
          else score += 1;
        }
      });

      // Bonus for multi-word sequence match (e.g., "empire fields" as a phrase)
      var nameWords = name.split(/\s+/);
      for (var i = 0; i < uniqueWords.length - 1; i++) {
        var bigram = uniqueWords[i] + ' ' + uniqueWords[i + 1];
        if (name.includes(bigram)) score += 5;
      }

      return { feature: feature, score: score };
    });

    return scored
      .filter(function (s) { return s.score > 0; })
      .sort(function (a, b) { return b.score - a.score; });
  }

  /**
   * Extracts a numeric rating from caption text.
   * Looks for patterns like "7/10", "7.5/10", "8 / 10", "8.5 out of 10"
   */
  function extractRating(caption) {
    if (!caption) return null;

    // Match X/10 or X.X/10 patterns (with optional spaces)
    var patterns = [
      /(\d+\.?\d*)\s*\/\s*10/,          // 7.5/10, 7 / 10
      /(\d+\.?\d*)\s*out\s*of\s*10/i,    // 7.5 out of 10
      /rating[:\s]*(\d+\.?\d*)/i,         // rating: 7.5
      /score[:\s]*(\d+\.?\d*)/i           // score: 7.5
    ];

    for (var i = 0; i < patterns.length; i++) {
      var match = caption.match(patterns[i]);
      if (match) {
        var num = parseFloat(match[1]);
        if (num >= 0 && num <= 10) return num;
      }
    }

    // Handle range like "6-7/10" — take the average
    var rangeMatch = caption.match(/(\d+\.?\d*)\s*-\s*(\d+\.?\d*)\s*\/\s*10/);
    if (rangeMatch) {
      var low = parseFloat(rangeMatch[1]);
      var high = parseFloat(rangeMatch[2]);
      if (low >= 0 && low <= 10 && high >= 0 && high <= 10) {
        return Math.round(((low + high) / 2) * 10) / 10;
      }
    }

    return null;
  }

  // ── Linking Flow ─────────────────────────────────

  async function startLinking() {
    document.getElementById('uploadPhase').style.display = 'none';
    document.getElementById('linkingPhase').style.display = '';
    document.getElementById('progressBadge').style.display = '';

    await setupMap();
    await loadFountains();
    showCurrentPost();
  }

  async function setupMap() {
    state.map = L.map('map').setView(config.MAP_CENTER || [49.251, -123.060], config.MAP_ZOOM || 11);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap'
    }).addTo(state.map);

    // Map click for new fountain placement
    state.map.on('click', function (e) {
      if (state.addingNewFountain) {
        state.newFountainLatLng = e.latlng;
        document.getElementById('newFountainCoords').textContent =
          'Location: ' + e.latlng.lat.toFixed(6) + ', ' + e.latlng.lng.toFixed(6);

        // Show a temporary marker
        if (state.newFountainMarker) state.newFountainMarker.remove();
        state.newFountainMarker = L.marker(e.latlng, {
          icon: L.divIcon({
            className: '',
            html: '<div style="background:#f59e0b;width:16px;height:16px;border-radius:50%;border:3px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3)"></div>',
            iconSize: [16, 16],
            iconAnchor: [8, 8]
          })
        }).addTo(state.map);
      }
    });
  }

  async function loadFountains() {
    var geojson = await FountainData.fetchGeoData();
    state.fountains = Array.isArray(geojson.features) ? geojson.features : [];
    state.fountainList = FountainData.getPlainList(geojson);

    state.markerById.clear();
    state.markers.forEach(function (m) { m.remove(); });
    state.markers = [];

    state.fountains.forEach(function (feature) {
      var props = feature.properties || {};
      var coords = feature.geometry && feature.geometry.coordinates;
      if (!coords || coords.length < 2) return;

      var marker = L.circleMarker([coords[1], coords[0]], {
        radius: 7,
        color: '#6b7280',
        fillColor: '#9ca3af',
        fillOpacity: 0.6,
        weight: 1.5
      }).addTo(state.map);

      marker.on('click', function () {
        if (!state.addingNewFountain) {
          selectFountain(props, marker);
        }
      });

      marker.bindPopup(
        '<strong>' + escapeHtml(props.name || 'Unnamed') + '</strong><br>' +
        '<small>' + escapeHtml(props.neighborhood || '') + '</small>'
      );

      state.markerById.set(props.supabase_id || props.id, marker);
      state.markers.push(marker);
    });
  }

  function showCurrentPost() {
    if (state.currentIndex >= state.posts.length) {
      finishLinking();
      return;
    }

    var post = state.posts[state.currentIndex];
    updateProgress();
    clearSelection();

    // Render post card
    var card = document.getElementById('postCard');
    card.innerHTML =
      '<div class="meta"><strong>Post ' + (state.currentIndex + 1) + ' of ' + state.posts.length + '</strong>' +
      (post.dateStr ? ' &middot; ' + escapeHtml(post.dateStr) : '') +
      (post.permalink ? ' &middot; <a href="' + escapeHtml(post.permalink) + '" target="_blank">View on IG</a>' : '') +
      '</div>' +
      '<div class="caption mt-2">' + escapeHtml(post.caption) + '</div>';

    // Auto-extract rating
    var rating = extractRating(post.caption);
    var ratingInput = document.getElementById('ratingInput');
    ratingInput.value = rating !== null ? rating : '';

    // Fuzzy match
    var matches = fuzzyMatchFountains(post.caption, state.fountains);
    var matchInfo = document.getElementById('matchInfo');

    if (matches.length > 0) {
      var best = matches[0];
      var props = best.feature.properties || {};
      matchInfo.innerHTML =
        '<h6><i class="fas fa-magic"></i> Best match (score: ' + best.score + ')</h6>' +
        '<strong>' + escapeHtml(props.name || 'Unnamed') + '</strong>' +
        (props.neighborhood ? '<br><small>' + escapeHtml(props.neighborhood) + '</small>' : '') +
        (matches.length > 1 ? '<br><small class="text-muted">' + (matches.length - 1) + ' other possible matches</small>' : '');
      matchInfo.className = 'match-info';

      // Auto-select the best match
      var marker = state.markerById.get(props.supabase_id || props.id);
      if (marker) {
        selectFountain(props, marker);
        state.map.setView(marker.getLatLng(), 15);
      }
    } else {
      matchInfo.innerHTML =
        '<h6><i class="fas fa-question-circle"></i> No auto-match</h6>' +
        '<small>Click a fountain on the map or search by name.</small>';
      matchInfo.className = 'match-info';
    }
  }

  function selectFountain(props, marker) {
    // Deselect previous
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({ fillColor: '#9ca3af', color: '#6b7280', radius: 7 });
    }

    // Highlight new
    if (marker) {
      marker.setStyle({ fillColor: '#198754', color: '#198754', radius: 11 });
      state.selectedMarker = marker;
    }

    state.selectedFountain = props;
    document.getElementById('confirmBtn').disabled = false;

    var matchInfo = document.getElementById('matchInfo');
    matchInfo.innerHTML =
      '<h6><i class="fas fa-check-circle text-success"></i> Selected</h6>' +
      '<strong>' + escapeHtml(props.name || 'Unnamed') + '</strong>' +
      (props.neighborhood ? '<br><small>' + escapeHtml(props.neighborhood) + '</small>' : '');
    matchInfo.className = 'match-info confirmed';
  }

  function clearSelection() {
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({ fillColor: '#9ca3af', color: '#6b7280', radius: 7 });
    }
    state.selectedMarker = null;
    state.selectedFountain = null;
    document.getElementById('confirmBtn').disabled = true;
    state.addingNewFountain = false;
    document.getElementById('newFountainPanel').style.display = 'none';
    if (state.newFountainMarker) {
      state.newFountainMarker.remove();
      state.newFountainMarker = null;
    }
  }

  // ── Actions ──────────────────────────────────────

  function setupActions() {
    document.getElementById('confirmBtn').addEventListener('click', confirmAndNext);
    document.getElementById('skipBtn').addEventListener('click', skipPost);
    document.getElementById('addFountainBtn').addEventListener('click', startAddFountain);
    document.getElementById('saveNewFountain').addEventListener('click', saveNewFountain);
    document.getElementById('cancelNewFountain').addEventListener('click', cancelNewFountain);

    // Search
    var searchInput = document.getElementById('fountainSearch');
    searchInput.addEventListener('input', function () {
      var query = searchInput.value.trim().toLowerCase();
      if (query.length < 2) return;
      var match = state.fountains.find(function (f) {
        var p = f.properties || {};
        return (p.name || '').toLowerCase().includes(query) ||
               (p.neighborhood || '').toLowerCase().includes(query);
      });
      if (match) {
        var props = match.properties || {};
        var marker = state.markerById.get(props.supabase_id || props.id);
        if (marker) {
          state.map.setView(marker.getLatLng(), 15);
          marker.openPopup();
        }
      }
    });
  }

  async function confirmAndNext() {
    if (!state.selectedFountain || !state.isAdmin) return;

    var post = state.posts[state.currentIndex];
    var ratingInput = document.getElementById('ratingInput');
    var rating = parseFloat(ratingInput.value);

    if (!rating || rating < 0 || rating > 10) {
      ui.toast('Enter a valid rating (0-10).', 'warning');
      return;
    }

    var fountainId = state.selectedFountain.supabase_id;
    if (!fountainId) {
      ui.toast('No Supabase ID for this fountain. Cannot save.', 'error');
      return;
    }

    var payload = {
      fountain_id: fountainId,
      author_type: 'admin',
      status: 'approved',
      rating: rating,
      review_text: post.caption || null,
      instagram_url: post.permalink || null,
      instagram_caption: post.caption || null,
      visit_date: post.dateStr || null,
      reviewed_at: post.dateStr ? post.dateStr + 'T12:00:00Z' : new Date().toISOString()
    };

    try {
      await api.insertAdminReview(payload, state.supabaseClient);
      state.linked++;
      ui.toast('Linked! (' + state.linked + ' total)', 'success');
      state.currentIndex++;
      showCurrentPost();
    } catch (e) {
      ui.toast('Save failed: ' + e.message, 'error');
      console.error(e);
    }
  }

  function skipPost() {
    state.skipped++;
    state.currentIndex++;
    showCurrentPost();
  }

  // ── New Fountain ─────────────────────────────────

  function startAddFountain() {
    state.addingNewFountain = true;
    state.newFountainLatLng = null;
    document.getElementById('newFountainPanel').style.display = '';
    document.getElementById('newFountainName').value = '';
    document.getElementById('newFountainCoords').textContent = 'Click the map to place it.';
    ui.toast('Click the map to place the new fountain.', 'info');
  }

  function cancelNewFountain() {
    state.addingNewFountain = false;
    document.getElementById('newFountainPanel').style.display = 'none';
    if (state.newFountainMarker) {
      state.newFountainMarker.remove();
      state.newFountainMarker = null;
    }
  }

  async function saveNewFountain() {
    var name = document.getElementById('newFountainName').value.trim();
    if (!name) { ui.toast('Enter a fountain name.', 'warning'); return; }
    if (!state.newFountainLatLng) { ui.toast('Click the map to set location.', 'warning'); return; }

    // Find nearest fountain for neighbourhood
    var nearest = findNearestFountain(state.newFountainLatLng.lat, state.newFountainLatLng.lng);
    var neighbourhood = nearest ? (nearest.properties || {}).neighborhood : null;

    // Look up Vancouver city ID
    try {
      var cityResult = await state.supabaseClient
        .from('cities')
        .select('id')
        .eq('slug', 'vancouver')
        .maybeSingle();

      var cityId = cityResult.data ? cityResult.data.id : null;

      var insertResult = await state.supabaseClient
        .from('fountains')
        .insert({
          name: name,
          latitude: state.newFountainLatLng.lat,
          longitude: state.newFountainLatLng.lng,
          neighbourhood: neighbourhood,
          city_id: cityId,
          operational_status: 'unknown',
          pet_friendly: 'unknown'
        })
        .select('id, name, neighbourhood, latitude, longitude')
        .single();

      if (insertResult.error) throw insertResult.error;

      var newFountain = insertResult.data;
      ui.toast('Fountain "' + name + '" created!', 'success');

      // Add marker to map and select it
      var marker = L.circleMarker(
        [newFountain.latitude, newFountain.longitude],
        { radius: 11, color: '#198754', fillColor: '#198754', fillOpacity: 0.7, weight: 2 }
      ).addTo(state.map);

      var props = {
        supabase_id: newFountain.id,
        name: newFountain.name,
        neighborhood: newFountain.neighbourhood
      };

      state.markerById.set(newFountain.id, marker);
      state.markers.push(marker);

      cancelNewFountain();
      selectFountain(props, marker);

    } catch (e) {
      ui.toast('Failed to create fountain: ' + e.message, 'error');
      console.error(e);
    }
  }

  function findNearestFountain(lat, lng) {
    var nearest = null;
    var minDist = Infinity;
    state.fountains.forEach(function (f) {
      var coords = f.geometry && f.geometry.coordinates;
      if (!coords) return;
      var d = Math.pow(coords[1] - lat, 2) + Math.pow(coords[0] - lng, 2);
      if (d < minDist) { minDist = d; nearest = f; }
    });
    return nearest;
  }

  // ── Progress & Finish ────────────────────────────

  function updateProgress() {
    var total = state.posts.length;
    var done = state.linked + state.skipped;
    document.getElementById('progressText').textContent = done + ' / ' + total + ' processed (' + state.linked + ' linked)';
  }

  function finishLinking() {
    document.getElementById('linkingPhase').style.display = 'none';
    document.getElementById('donePhase').style.display = '';
    document.getElementById('doneSummary').textContent =
      state.linked + ' posts linked to fountains. ' + state.skipped + ' skipped.';
  }

  // ── Utilities ────────────────────────────────────

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

**Step 2: Verify the full flow works**

1. Open `docs/link-instagram.html` in browser
2. Sign in with admin credentials
3. Create a test JSON file to verify parsing:

```json
[
  {
    "media": [
      {
        "uri": "media/posts/202505/photo.jpg",
        "creation_timestamp": 1715644800,
        "title": "Empire fields, south side by the basketball courts. 7/10."
      }
    ]
  },
  {
    "media": [
      {
        "uri": "media/posts/202505/photo2.jpg",
        "creation_timestamp": 1715731200,
        "title": "New Brighton Park fountain near the pool. Great pressure! 7.5/10"
      }
    ]
  }
]
```

4. Drop the test file. Verify:
   - "2 posts loaded" toast appears
   - First post shows with caption
   - Rating auto-extracts to 7
   - Fuzzy match highlights a fountain (Empire Fields area)
   - Map zooms to the match
   - Can click a different fountain to override
   - "Confirm & Next" writes to Supabase and advances
   - "Skip" advances without writing
   - Progress counter updates

5. Test "Add New Fountain":
   - Click "New Fountain" button
   - Type a name, click map for location
   - "Create Fountain" saves and selects it
   - Can then confirm the link

**Step 3: Commit**

```bash
git add docs/js/link-instagram.js
git commit -m "feat: add instagram linking tool with fuzzy match and rating extraction"
```

---

## Task 3: Apply data fixes for Hillcrest and Cambie fountains

**Files:**
- Modify: Supabase data (via the tool or direct SQL)

**Step 1: Identify correct coordinates**

Open the linking tool (or the main map at `docs/index.html`). Locate:
- **Hillcrest Park playground** — zoom in, find the actual playground location, note the lat/lng
- **Cambie & 33rd** — verify the correct position for "4963 Cambie St", note lat/lng

These are manual steps that require Katherine's input on the exact positions.

**Step 2: Update via Supabase SQL or dashboard**

For Hillcrest `DFPB0071`:
```sql
UPDATE fountains
SET latitude = [NEW_LAT], longitude = [NEW_LNG]
WHERE external_id = 'DFPB0071';
```

For Cambie `DFENG0047`:
```sql
UPDATE fountains
SET latitude = [NEW_LAT], longitude = [NEW_LNG], city_id = (SELECT id FROM cities WHERE slug = 'vancouver')
WHERE external_id = 'DFENG0047';
```

**Step 3: Verify on map**

Reload the map and confirm both points are in the correct locations.

---

## Task 4: Export Instagram data and run the backfill

**Step 1: Export Instagram data**

1. Open Instagram app or website
2. Go to Settings > Your Activity > Download Your Information
3. Select JSON format, select "Posts" (you can deselect other categories to speed it up)
4. Request download — Instagram emails you a link (can take up to 48 hours, usually much faster)
5. Download the ZIP, extract it, find `content/posts_1.json`

**Step 2: Run the linking tool**

1. Open `docs/link-instagram.html` in browser
2. Sign in with admin credentials
3. Drop `posts_1.json` onto the upload zone
4. Work through each post: confirm/adjust fountain match, confirm/adjust rating, click "Confirm & Next"
5. For fountains not in the database: use "New Fountain" to create them
6. Skip any posts that aren't fountain reviews (if any)

**Step 3: Verify in Supabase**

Check the reviews table in Supabase dashboard to confirm all linked posts appear with correct fountain_id, rating, and caption data.

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | HTML shell with layout, styles, dependencies | `docs/link-instagram.html` |
| 2 | Core JS: auth, parsing, fuzzy match, rating extraction, linking flow, new fountain creation | `docs/js/link-instagram.js` |
| 3 | Data fixes: Hillcrest + Cambie coordinates | Supabase SQL |
| 4 | Instagram export + run the backfill | Manual process |
