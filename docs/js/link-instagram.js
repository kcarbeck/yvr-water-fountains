'use strict';

(function () {
  const config = window.APP_CONFIG || {};
  const api = window.AppApi || {};
  const ui = window.AppUI || {};

  const state = {
    supabaseClient: null,
    isAdmin: false,
    fountains: [],
    posts: [],
    currentIndex: 0,
    linked: 0,
    skipped: 0,
    map: null,
    markers: [],
    markerById: new Map(),
    selectedFountain: null,
    selectedMarker: null,
    addingNewFountain: false,
    newFountainLatLng: null,
    newFountainMarker: null
  };

  document.addEventListener('DOMContentLoaded', init);

  function init() {
    setupAuth();
    setupFileUpload();
    setupActions();
  }

  // ── Auth ──────────────────────────────────────────

  function setupAuth() {
    const signInBtn = document.getElementById('authSignIn');
    const signOutBtn = document.getElementById('authSignOut');

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
      const email = document.getElementById('authEmail').value.trim();
      const password = document.getElementById('authPassword').value;
      if (!email || !password) return;
      try {
        const result = await state.supabaseClient.auth.signInWithPassword({ email: email, password: password });
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
      applySession(session).catch(function (e) { console.error('session apply failed', e); });
    });

    state.supabaseClient.auth.getSession().then(function (result) {
      const session = result.data && result.data.session ? result.data.session : null;
      applySession(session);
    });
  }

  async function applySession(session) {
    const signInBtn = document.getElementById('authSignIn');
    const signOutBtn = document.getElementById('authSignOut');
    const emailInput = document.getElementById('authEmail');
    const passwordInput = document.getElementById('authPassword');
    const mainContent = document.getElementById('mainContent');

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

    try {
      const profile = await api.fetchAdminProfile(session.user.id, state.supabaseClient);
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
    const el = document.getElementById('authStatus');
    if (el) el.textContent = msg;
  }

  // ── File Upload & Parsing ────────────────────────

  function setupFileUpload() {
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');

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
      const text = await file.text();
      const json = JSON.parse(text);
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

  function parseInstagramExport(json) {
    let rawPosts = [];

    if (Array.isArray(json)) {
      json.forEach(function (item) {
        if (item.media && Array.isArray(item.media)) {
          item.media.forEach(function (m) { rawPosts.push(m); });
        } else if (item.creation_timestamp || item.taken_at) {
          rawPosts.push(item);
        }
      });
    } else if (typeof json === 'object' && json !== null) {
      const candidates = ['ig_media', 'ig_reels_media', 'posts', 'media', 'photos_and_videos'];
      for (let i = 0; i < candidates.length; i++) {
        if (Array.isArray(json[candidates[i]])) {
          json[candidates[i]].forEach(function (item) {
            if (item.media && Array.isArray(item.media)) {
              item.media.forEach(function (m) { rawPosts.push(m); });
            } else if (item.creation_timestamp || item.taken_at) {
              rawPosts.push(item);
            }
          });
          if (rawPosts.length > 0) break;
        }
      }
      if (rawPosts.length === 0 && json.content && Array.isArray(json.content)) {
        json.content.forEach(function (item) {
          if (item.media && Array.isArray(item.media)) {
            item.media.forEach(function (m) { rawPosts.push(m); });
          }
        });
      }
    }

    return rawPosts.map(function (post) {
      let caption = post.title || post.caption || post.text || '';
      if (typeof caption === 'object' && caption.text) caption = caption.text;

      const timestamp = post.creation_timestamp || post.taken_at || post.timestamp;
      const date = timestamp ? new Date(timestamp * 1000) : null;

      const uri = post.uri || post.media_url || post.url || '';
      const permalink = post.permalink || post.link || '';

      return {
        caption: caption,
        date: date,
        dateStr: date ? date.toISOString().split('T')[0] : null,
        mediaUri: uri,
        permalink: permalink,
        raw: post
      };
    }).filter(function (p) {
      return p.caption && p.caption.trim().length > 0;
    }).sort(function (a, b) {
      if (!a.date) return 1;
      if (!b.date) return -1;
      return a.date - b.date;
    });
  }

  // ── Fuzzy Matching ───────────────────────────────

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
          if (name.includes(word)) score += 3;
          else score += 1;
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

  function extractRating(caption) {
    if (!caption) return null;

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

    for (let i = 0; i < patterns.length; i++) {
      const match = caption.match(patterns[i]);
      if (match) {
        const num = parseFloat(match[1]);
        if (num >= 0 && num <= 10) return num;
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

    state.map.on('click', function (e) {
      if (state.addingNewFountain) {
        state.newFountainLatLng = e.latlng;
        document.getElementById('newFountainCoords').textContent =
          'Location: ' + e.latlng.lat.toFixed(6) + ', ' + e.latlng.lng.toFixed(6);

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
    const geojson = await FountainData.fetchGeoData();
    state.fountains = Array.isArray(geojson.features) ? geojson.features : [];

    state.markerById.clear();
    state.markers.forEach(function (m) { m.remove(); });
    state.markers = [];

    state.fountains.forEach(function (feature) {
      const props = feature.properties || {};
      const coords = feature.geometry && feature.geometry.coordinates;
      if (!coords || coords.length < 2) return;

      const marker = L.circleMarker([coords[1], coords[0]], {
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

    const post = state.posts[state.currentIndex];
    updateProgress();
    clearSelection();

    const card = document.getElementById('postCard');
    const permalinkHtml = (post.permalink && isSafeUrl(post.permalink))
      ? ' &middot; <a href="' + escapeHtml(post.permalink) + '" target="_blank">View on IG</a>'
      : '';
    card.innerHTML =
      '<div class="meta"><strong>Post ' + (state.currentIndex + 1) + ' of ' + state.posts.length + '</strong>' +
      (post.dateStr ? ' &middot; ' + escapeHtml(post.dateStr) : '') +
      permalinkHtml +
      '</div>' +
      '<div class="caption mt-2">' + escapeHtml(post.caption) + '</div>';

    const rating = extractRating(post.caption);
    const ratingInput = document.getElementById('ratingInput');
    ratingInput.value = rating !== null ? rating : '';

    const matches = fuzzyMatchFountains(post.caption, state.fountains);
    const matchInfo = document.getElementById('matchInfo');

    if (matches.length > 0) {
      const best = matches[0];
      const props = best.feature.properties || {};
      matchInfo.innerHTML =
        '<h6><i class="fas fa-magic"></i> Best match (score: ' + best.score + ')</h6>' +
        '<strong>' + escapeHtml(props.name || 'Unnamed') + '</strong>' +
        (props.neighborhood ? '<br><small>' + escapeHtml(props.neighborhood) + '</small>' : '') +
        (matches.length > 1 ? '<br><small class="text-muted">' + (matches.length - 1) + ' other possible matches</small>' : '');
      matchInfo.className = 'match-info';

      const marker = state.markerById.get(props.supabase_id || props.id);
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
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({ fillColor: '#9ca3af', color: '#6b7280', radius: 7 });
    }

    if (marker) {
      marker.setStyle({ fillColor: '#198754', color: '#198754', radius: 11 });
      state.selectedMarker = marker;
    }

    state.selectedFountain = props;
    document.getElementById('confirmBtn').disabled = false;

    const matchInfo = document.getElementById('matchInfo');
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

    const searchInput = document.getElementById('fountainSearch');
    searchInput.addEventListener('input', function () {
      const query = searchInput.value.trim().toLowerCase();
      if (query.length < 2) return;
      const match = state.fountains.find(function (f) {
        const p = f.properties || {};
        return (p.name || '').toLowerCase().includes(query) ||
               (p.neighborhood || '').toLowerCase().includes(query);
      });
      if (match) {
        const props = match.properties || {};
        const marker = state.markerById.get(props.supabase_id || props.id);
        if (marker) {
          state.map.setView(marker.getLatLng(), 15);
          marker.openPopup();
        }
      }
    });
  }

  async function confirmAndNext() {
    if (!state.selectedFountain || !state.isAdmin) return;

    const confirmBtn = document.getElementById('confirmBtn');
    confirmBtn.disabled = true;

    const post = state.posts[state.currentIndex];
    const ratingInput = document.getElementById('ratingInput');
    const rating = parseFloat(ratingInput.value);

    if (rating === null || isNaN(rating) || rating < 0 || rating > 10) {
      ui.toast('Enter a valid rating (0-10).', 'warning');
      confirmBtn.disabled = false;
      return;
    }

    const fountainId = state.selectedFountain.supabase_id;
    if (!fountainId) {
      ui.toast('No Supabase ID for this fountain. Cannot save.', 'error');
      confirmBtn.disabled = false;
      return;
    }

    if (!api.insertAdminReview) {
      ui.toast('Supabase API helpers are not available.', 'error');
      confirmBtn.disabled = false;
      return;
    }

    // Check for duplicate (same fountain + same instagram URL)
    if (post.permalink) {
      try {
        const { data: existing } = await state.supabaseClient
          .from('reviews')
          .select('id')
          .eq('fountain_id', fountainId)
          .eq('instagram_url', post.permalink)
          .maybeSingle();

        if (existing) {
          ui.toast('This post is already linked to this fountain.', 'warning');
          confirmBtn.disabled = false;
          return;
        }
      } catch (e) {
        console.warn('duplicate check failed, proceeding anyway', e);
      }
    }

    const payload = {
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
      confirmBtn.disabled = false;
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
    const name = document.getElementById('newFountainName').value.trim();
    if (!name) { ui.toast('Enter a fountain name.', 'warning'); return; }
    if (!state.newFountainLatLng) { ui.toast('Click the map to set location.', 'warning'); return; }

    const nearest = findNearestFountain(state.newFountainLatLng.lat, state.newFountainLatLng.lng);
    const neighbourhood = nearest ? (nearest.properties || {}).neighborhood : null;

    try {
      const cityResult = await state.supabaseClient
        .from('cities')
        .select('id')
        .eq('slug', 'vancouver')
        .maybeSingle();

      const cityId = cityResult.data ? cityResult.data.id : null;

      const insertResult = await state.supabaseClient
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

      const newFountain = insertResult.data;
      ui.toast('Fountain "' + name + '" created!', 'success');

      const marker = L.circleMarker(
        [newFountain.latitude, newFountain.longitude],
        { radius: 11, color: '#198754', fillColor: '#198754', fillOpacity: 0.7, weight: 2 }
      ).addTo(state.map);

      const props = {
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
    let nearest = null;
    let minDist = Infinity;
    state.fountains.forEach(function (f) {
      const coords = f.geometry && f.geometry.coordinates;
      if (!coords) return;
      const d = Math.pow(coords[1] - lat, 2) + Math.pow(coords[0] - lng, 2);
      if (d < minDist) { minDist = d; nearest = f; }
    });
    return nearest;
  }

  // ── Progress & Finish ────────────────────────────

  function updateProgress() {
    const total = state.posts.length;
    const done = state.linked + state.skipped;
    document.getElementById('progressText').textContent = done + ' / ' + total + ' processed (' + state.linked + ' linked)';
  }

  function finishLinking() {
    document.getElementById('linkingPhase').style.display = 'none';
    document.getElementById('donePhase').style.display = '';
    document.getElementById('doneSummary').textContent =
      state.linked + ' posts linked to fountains. ' + state.skipped + ' skipped.';
  }

  // ── Utilities ────────────────────────────────────

  function isSafeUrl(url) {
    if (!url) return false;
    try {
      const parsed = new URL(url);
      return parsed.protocol === 'http:' || parsed.protocol === 'https:';
    } catch (e) {
      return false;
    }
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
