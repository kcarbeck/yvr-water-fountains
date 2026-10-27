'use strict';

// Review page. Admins sign in with an emailed code, then add reviews in three
// steps (fountain, rating, details), approve public reviews and fix their own.
// The public form is not built yet, so everyone else sees the closed notice.
// Database text is only ever written with textContent, never innerHTML.
(function () {
  // ---- Settings ----
  const NEARBY_COUNT = 4;        // fountains listed under "Right here" and "Farther away"
  const CLOSE_ENOUGH_M = 300;    // nearest fountain farther than this: suggest search
  const SEARCH_LIMIT = 8;        // search results shown
  const RECENT_LIMIT = 10;       // reviews listed under "My recent"
  const RESEND_SECONDS = 60;     // wait before a new code can be requested
  const TIME_ZONE = 'America/Vancouver';

  const state = {
    client: null,
    user: null,
    admin: null,            // row from public.admins
    fountains: [],          // rows from fountain_overview_view
    fountainById: new Map(),
    position: null,         // phone location, kept in memory only
    pickMap: null,
    youMarker: null,
    draft: null             // the review being added or fixed
  };

  const $ = (id) => document.getElementById(id);

  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    wireEvents();
    state.client = window.AppApi && window.AppApi.getClient();
    if (!state.client) {
      showOnly('view-offline');
      return;
    }

    try {
      await loadFountains();
    } catch (error) {
      console.error('could not load fountains', error);
      showOnly('view-offline');
      return;
    }

    const { data } = await state.client.auth.getSession();
    await afterSignIn(data && data.session ? data.session.user : null);
  }

  // ---- Sign-in ----

  async function afterSignIn(user) {
    state.user = user;
    state.admin = null;
    if (user) {
      try {
        state.admin = await window.AppApi.fetchAdminProfile(user.id);
      } catch (error) {
        console.error('admin check failed', error);
      }
    }

    if (!state.admin) {
      $('no-access').hidden = !user;
      $('show-sign-in').hidden = Boolean(user);
      showOnly('view-closed');
      return;
    }

    const name = state.admin.display_name || user.email;
    $('admin-name').textContent = name;
    document.querySelectorAll('[data-admin-name]').forEach((node) => { node.textContent = name; });
    $('admin-bar').hidden = false;
    $('tabs').hidden = false;
    refreshWaitingCount();
    startNewReview(new URLSearchParams(window.location.search).get('fountain'));
  }

  async function sendCode() {
    const email = $('email').value.trim();
    if (!email) {
      signInMessage('Enter your email first.');
      return;
    }
    $('send-code').disabled = true;
    const { error } = await state.client.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: false }   // invite-only: no new accounts from this page
    });
    $('send-code').disabled = false;
    if (error) {
      console.error('send code failed', error);
      signInMessage(/signups not allowed|not found/i.test(error.message)
        ? 'That email is not invited. Ask Katherine to add you.'
        : 'Could not send a code. Wait a minute and try again.');
      return;
    }
    signInMessage('Code sent to ' + email + '.');
    $('code-block').hidden = false;
    $('code').focus();
    startResendTimer();
  }

  function startResendTimer() {
    const button = $('resend-code');
    let left = RESEND_SECONDS;
    button.disabled = true;
    button.textContent = 'resend in ' + left + ' s';
    const timer = setInterval(() => {
      left -= 1;
      button.textContent = left > 0 ? 'resend in ' + left + ' s' : 'resend';
      if (left <= 0) {
        clearInterval(timer);
        button.disabled = false;
      }
    }, 1000);
  }

  async function verifyCode() {
    const email = $('email').value.trim();
    const token = $('code').value.trim();
    if (!/^\d{6}$/.test(token)) {
      signInMessage('The code is 6 digits.');
      return;
    }
    $('verify-code').disabled = true;
    const { data, error } = await state.client.auth.verifyOtp({ email, token, type: 'email' });
    $('verify-code').disabled = false;
    if (error) {
      console.error('verify failed', error);
      signInMessage('That code did not work. Check it, or ask for a new one.');
      return;
    }
    $('sign-in-message').hidden = true;
    await afterSignIn(data.user);
  }

  async function signOut() {
    await state.client.auth.signOut();
    $('admin-bar').hidden = true;
    $('tabs').hidden = true;
    await afterSignIn(null);
  }

  function signInMessage(text) {
    $('sign-in-message').textContent = text;
    $('sign-in-message').hidden = false;
  }

  // ---- Step 1: which fountain ----

  function startNewReview(fountainId) {
    state.draft = { editingId: null, fountainId: null, rating: null, half: false, note: '', visitDate: todayInVancouver(), link: '' };
    selectTab('add');
    if (fountainId && state.fountainById.has(fountainId)) {
      state.draft.fountainId = fountainId;
      showRate();
    } else {
      showPick();
    }
  }

  function showPick() {
    showOnly('view-pick');
    if (!state.pickMap) {
      buildPickMap();
      locate();
    }
    state.pickMap.invalidateSize();
  }

  function buildPickMap() {
    state.pickMap = L.map('pick-map').setView(window.APP_CONFIG.MAP_CENTER, 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap' }).addTo(state.pickMap);
    state.fountains.forEach((fountain) => {
      L.circleMarker([fountain.latitude, fountain.longitude], {
        radius: 7, color: '#1a1a2e', weight: 1.5, fillOpacity: 0.85,
        fillColor: fountain.latest_review_rating !== null ? '#c8ff00' : '#c5a3ff'
      }).on('click', () => chooseFountain(fountain.id)).addTo(state.pickMap);
    });
  }

  function locate() {
    if (!navigator.geolocation) {
      locationNote('This browser cannot share your location. Search instead.');
      return;
    }
    locationNote('Finding you...');
    navigator.geolocation.getCurrentPosition((position) => {
      state.position = { lat: position.coords.latitude, lng: position.coords.longitude };
      const accuracy = Math.round(position.coords.accuracy);
      locationNote('Drag to look around, then tap your fountain. Accurate to about ' + accuracy + ' m.');
      if (state.youMarker) {
        state.youMarker.remove();
      }
      state.youMarker = L.circleMarker([state.position.lat, state.position.lng], {
        radius: 8, color: '#ffffff', weight: 3, fillColor: '#2f6fed', fillOpacity: 1
      }).addTo(state.pickMap);
      state.pickMap.setView([state.position.lat, state.position.lng], 17);
      renderNearby();
    }, () => {
      locationNote('Location is off or unavailable. Search instead.');
      $('search').focus();
    }, { enableHighAccuracy: true, timeout: 15000 });
  }

  function locationNote(text) {
    $('location-note').textContent = text;
  }

  function renderNearby() {
    const list = $('nearby-list');
    list.replaceChildren();
    if (!state.position) {
      return;
    }
    // Fountains stacked at one spot are listed once; tapping opens the spot's picker.
    const seenSpots = new Set();
    const nearest = state.fountains
      .map((fountain) => ({ fountain, metres: distanceMetres(state.position, fountain) }))
      .sort((a, b) => a.metres - b.metres)
      .filter((item) => {
        const spot = item.fountain.latitude + ',' + item.fountain.longitude;
        if (seenSpots.has(spot)) {
          return false;
        }
        seenSpots.add(spot);
        return true;
      })
      .slice(0, NEARBY_COUNT);

    if (nearest[0].metres <= CLOSE_ENOUGH_M) {
      list.append(heading('Right here'));
      list.append(fountainButton(nearest[0].fountain, nearest[0].metres, 'here'));
      list.append(heading('Farther away'));
    } else {
      list.append(paragraph('None of these look close. Try search.', 'notice'));
    }
    nearest.slice(nearest[0].metres <= CLOSE_ENOUGH_M ? 1 : 0).forEach((item) => {
      list.append(fountainButton(item.fountain, item.metres));
    });
  }

  function renderSearch() {
    const results = $('search-results');
    results.replaceChildren();
    const words = $('search').value.trim().toLowerCase();
    if (words.length < 2) {
      return;
    }
    const matches = state.fountains.filter((fountain) => {
      const text = [fountain.name, fountain.neighbourhood, fountain.location_description].join(' ').toLowerCase();
      return text.includes(words);
    });
    if (matches.length === 0) {
      results.append(paragraph('No fountain matches that.', 'muted'));
      return;
    }
    matches.slice(0, SEARCH_LIMIT).forEach((fountain) => {
      const metres = state.position ? distanceMetres(state.position, fountain) : null;
      results.append(fountainButton(fountain, metres));
    });
  }

  // One tappable row: name, where it is, latest rating, distance.
  function fountainButton(fountain, metres, extraClass) {
    const button = el('button', 'pick-row' + (extraClass ? ' ' + extraClass : ''));
    button.type = 'button';
    const text = el('span');
    text.append(el('span', 'pick-name', fountain.name));
    const where = [fountain.location_description, fountain.neighbourhood].filter(Boolean).join(' · ');
    if (where) {
      text.append(el('span', 'pick-sub', where));
    }
    const stacked = sameSpot(fountain).length;
    text.append(el('span', 'pick-sub', stacked > 1 ? stacked + ' fountains at this spot' : latestLine(fountain)));
    button.append(text);
    if (metres !== null && metres !== undefined) {
      button.append(el('span', 'distance', formatDistance(metres)));
    }
    button.addEventListener('click', () => chooseFountain(fountain.id));
    return button;
  }

  function chooseFountain(fountainId) {
    const others = sameSpot(state.fountainById.get(fountainId));
    if (others.length > 1) {
      showCluster(others);
      return;
    }
    state.draft.fountainId = fountainId;
    showRate();
  }

  // Several fountains share these coordinates (mostly Burnaby rec centres).
  function showCluster(fountains) {
    $('cluster-intro').textContent = fountains.length + ' fountains are listed at this spot. Which one?';
    const list = $('cluster-list');
    list.replaceChildren();
    fountains.forEach((other) => {
      const button = el('button', 'pick-row');
      button.type = 'button';
      const text = el('span');
      text.append(el('span', 'pick-name', other.name));
      text.append(el('span', 'pick-sub', other.location_description || 'No description yet'));
      text.append(el('span', 'pick-sub', latestLine(other)));
      button.append(text);
      button.addEventListener('click', () => {
        state.draft.fountainId = other.id;
        showRate();
      });
      list.append(button);
    });
    showOnly('view-cluster');
  }

  // ---- Step 2: rating ----

  function showRate() {
    showFountainName();
    renderChips();
    showOnly('view-rate');
  }

  function renderChips() {
    const chips = $('chips');
    chips.replaceChildren();
    for (let value = 0; value <= 10; value += 1) {
      const chip = el('button', 'chip', String(value));
      chip.type = 'button';
      chip.setAttribute('aria-pressed', String(state.draft.rating === value));
      chip.addEventListener('click', () => {
        state.draft.rating = value;
        if (value === 10) {
          state.draft.half = false;
        }
        renderChips();
      });
      chips.append(chip);
    }
    const half = el('button', 'chip', '+½');
    half.type = 'button';
    half.setAttribute('aria-label', 'Add a half point');
    half.setAttribute('aria-pressed', String(state.draft.half));
    half.disabled = state.draft.rating === null || state.draft.rating === 10;
    half.addEventListener('click', () => {
      state.draft.half = !state.draft.half;
      renderChips();
    });
    chips.append(half);

    const rating = currentRating();
    $('rating-badge').hidden = rating === null;
    $('rating-badge').textContent = rating === null ? '' : formatRating(rating) + ' / 10';
    $('rate-next').disabled = rating === null;
  }

  function currentRating() {
    if (state.draft.rating === null) {
      return null;
    }
    return state.draft.rating + (state.draft.half ? 0.5 : 0);
  }

  // ---- Step 3: details and save ----

  function showDetails() {
    $('details-rating').textContent = formatRating(currentRating()) + ' / 10';
    $('note').value = state.draft.note;
    $('note-count').textContent = String(state.draft.note.length);
    $('visit-date').value = state.draft.visitDate;
    $('visit-date').max = todayInVancouver();
    $('post-link').value = state.draft.link;
    $('save-message').hidden = true;
    $('save').textContent = state.draft.editingId ? 'Save changes' : 'Save and publish';
    showOnly('view-details');
  }

  async function save() {
    const draft = state.draft;
    draft.note = $('note').value.trim();
    draft.visitDate = $('visit-date').value;
    draft.link = $('post-link').value.trim();

    if (!draft.visitDate || draft.visitDate > todayInVancouver() || draft.visitDate < '2020-01-01') {
      saveMessage('Pick a visit date between 2020 and today.');
      return;
    }
    let link = null;
    if (draft.link) {
      link = normalisePostLink(draft.link);
      if (!link) {
        saveMessage('That does not look like an Instagram post link (instagram.com/p/... or /reel/...).');
        return;
      }
      const clash = await findReviewWithLink(link, draft.editingId);
      if (clash) {
        saveMessage(clash);
        return;
      }
    }

    const fields = {
      fountain_id: draft.fountainId,
      rating: currentRating(),
      review_text: draft.note || null,
      visit_date: draft.visitDate,
      instagram_url: link
    };

    $('save').disabled = true;
    let result;
    if (draft.editingId) {
      result = await state.client.from('reviews').update(fields).eq('id', draft.editingId);
    } else {
      result = await state.client.from('reviews').insert(Object.assign(fields, {
        author_type: 'admin',
        status: 'approved',
        reviewer_name: state.admin.display_name,
        approved_by: state.user.id,
        reviewed_at: new Date().toISOString()
      }));
    }
    $('save').disabled = false;

    if (result.error) {
      console.error('save failed', result.error);
      saveMessage(result.error.code === '23505'
        ? 'That post link is already on another review.'
        : 'Could not save. Your review is still here; try again.');
      return;
    }

    draft.link = link || '';
    showDone();
    loadFountains().catch((error) => console.error('could not refresh fountains', error));
  }

  function saveMessage(text) {
    $('save-message').textContent = text;
    $('save-message').hidden = false;
  }

  // Returns a message if another review already has this post, else null.
  async function findReviewWithLink(link, ignoreId) {
    const code = link.split('/')[4];
    const { data, error } = await state.client
      .from('reviews')
      .select('id, fountain_id, visit_date')
      .in('instagram_url', ['https://www.instagram.com/p/' + code + '/', 'https://www.instagram.com/reel/' + code + '/']);
    if (error) {
      console.error('duplicate check failed', error);
      return null;   // the unique index still refuses a true duplicate
    }
    const other = (data || []).find((row) => row.id !== ignoreId);
    if (!other) {
      return null;
    }
    return 'Already reviewed: ' + fountainName(other.fountain_id) + ', ' + formatDate(other.visit_date) + '.';
  }

  function showDone() {
    const fountain = state.fountainById.get(state.draft.fountainId);
    showFountainName();
    $('done-rating').textContent = formatRating(currentRating()) + ' / 10';
    $('done-summary').textContent = [
      formatDate(state.draft.visitDate),
      state.admin.display_name,
      state.draft.link ? 'post linked' : 'no post link yet'
    ].join(' · ');
    $('done-map-link').href = 'map.html#' + encodeURIComponent(fountain.external_id || fountain.id);
    showOnly('view-done');
  }

  // ---- Waiting: public reviews to approve, our reviews without a post ----

  async function showWaiting() {
    showOnly('view-waiting');
    $('waiting-message').hidden = true;
    const [pending, unlinked] = await Promise.all([fetchPending(), fetchUnlinked()]);
    if (!pending || !unlinked) {
      $('waiting-message').textContent = 'Could not load the queue. Try again in a minute.';
      $('waiting-message').hidden = false;
      return;
    }
    renderPending(pending);
    renderUnlinked(unlinked);
    setWaitingCount(pending.length + unlinked.length);
    if (pending.length + unlinked.length === 0) {
      $('waiting-message').textContent = 'Nothing waiting. Nice.';
      $('waiting-message').hidden = false;
    }
  }

  async function refreshWaitingCount() {
    const [pending, unlinked] = await Promise.all([fetchPending(), fetchUnlinked()]);
    if (pending && unlinked) {
      setWaitingCount(pending.length + unlinked.length);
    }
  }

  function setWaitingCount(count) {
    document.querySelector('[data-tab="waiting"]').textContent = count > 0 ? 'Waiting (' + count + ')' : 'Waiting';
  }

  async function fetchPending() {
    try {
      return await window.AppApi.fetchReviewsByStatus('pending');
    } catch (error) {
      console.error('pending load failed', error);
      return null;
    }
  }

  async function fetchUnlinked() {
    const { data, error } = await state.client
      .from('reviews')
      .select('id, fountain_id, rating, visit_date, reviewer_name')
      .eq('author_type', 'admin')
      .is('instagram_url', null)
      .order('created_at', { ascending: false });
    if (error) {
      console.error('unlinked load failed', error);
      return null;
    }
    return data || [];
  }

  function renderPending(reviews) {
    $('pending-count').textContent = String(reviews.length);
    const list = $('pending-list');
    list.replaceChildren();
    reviews.forEach((review) => {
      const item = el('div', 'list-item');
      item.append(titleRow(fountainName(review.fountain_id), formatRating(review.rating) + ' / 10'));
      item.append(el('div', 'muted', [
        review.reviewer_name || 'Anonymous',
        'visited ' + formatDate(review.visit_date),
        'sent ' + formatTimestamp(review.created_at)
      ].join(' · ')));
      if (review.review_text) {
        item.append(el('p', 'quote', review.review_text));
      }
      const actions = el('div', 'actions');
      actions.append(actionButton('Approve', 'go', () => moderate(review.id, 'approved')));
      actions.append(actionButton('Reject', '', () => moderate(review.id, 'rejected')));
      item.append(actions);
      list.append(item);
    });
  }

  async function moderate(reviewId, status) {
    const extra = { reviewed_at: new Date().toISOString(), approved_by: status === 'approved' ? state.user.id : null };
    try {
      await window.AppApi.updateReviewStatus(reviewId, status, extra);
    } catch (error) {
      console.error('moderation failed', error);
      alert('Could not save that. Try again.');
      return;
    }
    if (status === 'approved') {
      loadFountains().catch((error) => console.error('could not refresh fountains', error));
    }
    showWaiting();
  }

  function renderUnlinked(reviews) {
    $('unlinked-count').textContent = String(reviews.length);
    const list = $('unlinked-list');
    list.replaceChildren();
    reviews.forEach((review) => {
      const item = el('div', 'list-item');
      item.append(titleRow(fountainName(review.fountain_id) + ' · ' + formatRating(review.rating),
        (review.reviewer_name || 'us') + ' · ' + formatDate(review.visit_date)));
      const form = el('div', 'inline-form');
      const input = el('input');
      input.type = 'url';
      input.placeholder = 'Post link';
      input.setAttribute('aria-label', 'Post link for ' + fountainName(review.fountain_id));
      const message = el('p', 'notice error');
      message.hidden = true;
      form.append(input, actionButton('Add link', 'go', () => addLink(review.id, input.value, message)));
      item.append(form, message);
      list.append(item);
    });
  }

  async function addLink(reviewId, value, message) {
    const link = normalisePostLink(value.trim());
    if (!link) {
      message.textContent = 'That does not look like an Instagram post link.';
      message.hidden = false;
      return;
    }
    const clash = await findReviewWithLink(link, reviewId);
    if (clash) {
      message.textContent = clash;
      message.hidden = false;
      return;
    }
    const { error } = await state.client.from('reviews').update({ instagram_url: link }).eq('id', reviewId);
    if (error) {
      console.error('add link failed', error);
      message.textContent = 'Could not save the link. Try again.';
      message.hidden = false;
      return;
    }
    loadFountains().catch((err) => console.error('could not refresh fountains', err));
    showWaiting();
  }

  // ---- My recent: fix or delete my own reviews ----

  async function showRecent() {
    showOnly('view-recent');
    $('recent-message').hidden = true;
    const { data, error } = await state.client
      .from('reviews')
      .select('id, fountain_id, rating, review_text, visit_date, instagram_url, created_at')
      .eq('created_by', state.user.id)
      .order('created_at', { ascending: false })
      .limit(RECENT_LIMIT);
    const list = $('recent-list');
    list.replaceChildren();
    if (error) {
      console.error('recent load failed', error);
      recentMessage('Could not load your reviews. Try again in a minute.');
      return;
    }
    if (!data || data.length === 0) {
      recentMessage('No reviews added from this page yet.');
      return;
    }
    data.forEach((review) => {
      const item = el('div', 'list-item');
      item.append(titleRow(fountainName(review.fountain_id), formatRating(review.rating) + ' / 10'));
      item.append(el('div', 'muted', formatDate(review.visit_date) + (review.instagram_url ? ' · post linked' : ' · no post link')));
      if (review.review_text) {
        item.append(el('p', 'quote', review.review_text));
      }
      const actions = el('div', 'actions');
      actions.append(actionButton('Fix', 'go', () => startEdit(review)));
      actions.append(actionButton('Delete', '', () => deleteReview(review)));
      item.append(actions);
      list.append(item);
    });
  }

  function recentMessage(text) {
    $('recent-message').textContent = text;
    $('recent-message').hidden = false;
  }

  // Fixing reuses the three steps, starting at the rating with everything filled in.
  function startEdit(review) {
    const rating = Number(review.rating);
    state.draft = {
      editingId: review.id,
      fountainId: review.fountain_id,
      rating: Math.floor(rating),
      half: rating % 1 !== 0,
      note: review.review_text || '',
      visitDate: review.visit_date || todayInVancouver(),
      link: review.instagram_url || ''
    };
    selectTab('add');
    showRate();
  }

  async function deleteReview(review) {
    if (!confirm('Delete your review of ' + fountainName(review.fountain_id) + '? This cannot be undone.')) {
      return;
    }
    const { error } = await state.client.from('reviews').delete().eq('id', review.id);
    if (error) {
      console.error('delete failed', error);
      recentMessage('Could not delete it. Try again.');
      return;
    }
    loadFountains().catch((err) => console.error('could not refresh fountains', err));
    showRecent();
  }

  // ---- Page wiring ----

  function wireEvents() {
    $('show-sign-in').addEventListener('click', () => showOnly('view-sign-in'));
    $('send-code').addEventListener('click', sendCode);
    $('resend-code').addEventListener('click', sendCode);
    $('verify-code').addEventListener('click', verifyCode);
    $('locate').addEventListener('click', locate);
    $('search').addEventListener('input', renderSearch);
    $('rate-next').addEventListener('click', showDetails);
    $('save').addEventListener('click', save);
    $('note').addEventListener('input', () => { $('note-count').textContent = String($('note').value.length); });

    document.querySelectorAll('[data-action="sign-out"]').forEach((button) => button.addEventListener('click', signOut));
    document.querySelectorAll('[data-action="new-review"]').forEach((button) => button.addEventListener('click', () => startNewReview(null)));
    document.querySelectorAll('[data-goto="pick"]').forEach((button) => button.addEventListener('click', showPick));
    document.querySelectorAll('[data-tab]').forEach((button) => button.addEventListener('click', () => openTab(button.dataset.tab)));
    document.querySelectorAll('[data-tab-link]').forEach((button) => button.addEventListener('click', () => openTab(button.dataset.tabLink)));
  }

  function openTab(tab) {
    selectTab(tab);
    if (tab === 'add') {
      startNewReview(null);
    } else if (tab === 'waiting') {
      showWaiting();
    } else {
      showRecent();
    }
  }

  function selectTab(tab) {
    document.querySelectorAll('[data-tab]').forEach((button) => {
      button.setAttribute('aria-pressed', String(button.dataset.tab === tab));
    });
  }

  // Hides every view except one.
  function showOnly(viewId) {
    $('loading').hidden = true;
    document.querySelectorAll('.view').forEach((view) => { view.hidden = view.id !== viewId; });
    window.scrollTo(0, 0);
  }

  function showFountainName() {
    const name = fountainName(state.draft.fountainId);
    document.querySelectorAll('[data-fountain-name]').forEach((node) => { node.textContent = name; });
  }

  async function loadFountains() {
    const rows = await window.AppApi.fetchFountainOverview();
    state.fountains = rows.filter((row) => typeof row.latitude === 'number' && typeof row.longitude === 'number');
    state.fountainById = new Map(state.fountains.map((row) => [row.id, row]));
  }

  // ======================================================================
  // Helpers (don't normally edit)
  // ======================================================================

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) {
      node.className = className;
    }
    if (text !== undefined) {
      node.textContent = text;
    }
    return node;
  }

  function heading(text) {
    return el('h2', null, text);
  }

  function paragraph(text, className) {
    return el('p', className, text);
  }

  function titleRow(left, right) {
    const row = el('div', 'row');
    row.append(el('strong', null, left), el('span', 'rating-badge', right));
    return row;
  }

  function actionButton(label, extraClass, onClick) {
    const button = el('button', 'btn-small' + (extraClass ? ' ' + extraClass : ''), label);
    button.type = 'button';
    button.addEventListener('click', async () => {
      button.disabled = true;
      await onClick();
      button.disabled = false;
    });
    return button;
  }

  // All fountains with exactly the same coordinates as this one (itself included).
  function sameSpot(fountain) {
    return state.fountains.filter((other) =>
      other.latitude === fountain.latitude && other.longitude === fountain.longitude);
  }

  function fountainName(fountainId) {
    const fountain = state.fountainById.get(fountainId);
    return fountain ? fountain.name : 'Unknown fountain';
  }

  function latestLine(fountain) {
    if (fountain.latest_review_rating === null || fountain.latest_review_rating === undefined) {
      return 'Not reviewed yet';
    }
    const who = fountain.latest_review_author_type === 'admin' ? 'by us' : 'public';
    const when = fountain.latest_reviewed_at ? ', ' + formatTimestamp(fountain.latest_reviewed_at) : '';
    return 'Latest ' + formatRating(fountain.latest_review_rating) + ' ' + who + when;
  }

  // Accepts instagram.com/p/CODE or /reel/CODE with or without https, www or a
  // query string, and returns the form stored in the database, else null.
  function normalisePostLink(text) {
    const match = text.match(/^(?:https?:\/\/)?(?:www\.)?instagram\.com\/(p|reels?)\/([A-Za-z0-9_-]+)/i);
    if (!match) {
      return null;
    }
    const kind = match[1].toLowerCase() === 'p' ? 'p' : 'reel';
    return 'https://www.instagram.com/' + kind + '/' + match[2] + '/';
  }

  function distanceMetres(from, fountain) {
    const toRad = (degrees) => degrees * Math.PI / 180;
    const dLat = toRad(fountain.latitude - from.lat);
    const dLng = toRad(fountain.longitude - from.lng);
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(from.lat)) * Math.cos(toRad(fountain.latitude)) * Math.sin(dLng / 2) ** 2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  function formatDistance(metres) {
    return metres < 1000 ? Math.round(metres) + ' m' : (metres / 1000).toFixed(1) + ' km';
  }

  function formatRating(value) {
    const number = Number(value);
    return Number.isInteger(number) ? String(number) : number.toFixed(1);
  }

  function todayInVancouver() {
    return new Date().toLocaleDateString('en-CA', { timeZone: TIME_ZONE });   // YYYY-MM-DD
  }

  // '2026-10-14' -> '14 Oct 2026' without time zone shifts
  function formatDate(isoDate) {
    if (!isoDate) {
      return 'no date';
    }
    const [year, month, day] = isoDate.split('-').map(Number);
    return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString('en-GB', {
      day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC'
    });
  }

  function formatTimestamp(timestamp) {
    return new Date(timestamp).toLocaleDateString('en-GB', {
      day: 'numeric', month: 'short', year: 'numeric', timeZone: TIME_ZONE
    });
  }
})();
