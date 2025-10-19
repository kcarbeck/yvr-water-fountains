'use strict';

(function () {
  const api = window.AppApi || {};
  const ui = window.AppUI || {};
  const state = {
    supabaseClient: null,
    isAdmin: false,
    fountainById: new Map()
  };

  document.addEventListener('DOMContentLoaded', init);

  async function init() {
    if (!api.hasCredentials || !api.hasCredentials()) {
      setAuthMessage('supabase configuration missing. add your project url and anon key to config.js.');
      disableLogin();
      return;
    }

    state.supabaseClient = typeof api.getClient === 'function'
      ? api.getClient()
      : null;

    if (!state.supabaseClient) {
      setAuthMessage('supabase client failed to initialize. double-check your configuration values.');
      disableLogin();
      return;
    }

    setupAuthHandlers();
    setupRefreshButton();

    try {
      await loadFountainMap();
    } catch (error) {
      console.warn('unable to load fountain metadata for moderation view', error);
    }

    const { data } = await state.supabaseClient.auth.getSession();
    applySession(data && data.session ? data.session : null);
  }

  function setupAuthHandlers() {
    const loginForm = document.getElementById('loginForm');
    const logoutButton = document.getElementById('logoutButton');

    if (loginForm) {
      loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        const email = document.getElementById('moderatorEmail').value.trim();
        const password = document.getElementById('moderatorPassword').value;

        if (!email || !password) {
          setAuthMessage('enter both email and password to continue.');
          return;
        }

        try {
          const { error } = await state.supabaseClient.auth.signInWithPassword({ email, password });
          if (error) {
            setAuthMessage(`sign in failed: ${error.message}`);
            return;
          }
          setAuthMessage('sign in succeeded. checking admin permissions...');
        } catch (error) {
          console.error('sign in error', error);
          setAuthMessage('sign in failed due to a network issue. try again.');
        }
      });
    }

    if (logoutButton) {
      logoutButton.addEventListener('click', async () => {
        await state.supabaseClient.auth.signOut();
      });
    }

    state.supabaseClient.auth.onAuthStateChange((_event, session) => {
      applySession(session);
    });
  }

  function setupRefreshButton() {
    const refreshButton = document.getElementById('refreshButton');
    if (refreshButton) {
      refreshButton.addEventListener('click', async () => {
        await loadDashboard();
      });
    }
  }

  async function loadFountainMap() {
    const geojson = await FountainData.fetchGeoData();
    (geojson.features || []).forEach((feature) => {
      const props = feature.properties || {};
      if (props.supabase_id) {
        state.fountainById.set(props.supabase_id, props);
      }
    });
  }

  function applySession(session) {
    const loginForm = document.getElementById('loginForm');
    const logoutRow = document.getElementById('logoutRow');
    const signedInAs = document.getElementById('signedInAs');
    const adminControls = document.getElementById('adminControls');

    state.isAdmin = false;

    if (!session) {
      setAuthMessage('enter your supabase credentials to moderate reviews.');
      if (loginForm) {
        loginForm.style.display = 'block';
      }
      if (logoutRow) {
        logoutRow.style.display = 'none';
      }
      if (adminControls) {
        adminControls.style.display = 'none';
      }
      return;
    }

    if (loginForm) {
      loginForm.style.display = 'none';
    }
    if (logoutRow) {
      logoutRow.style.display = 'flex';
    }
    if (signedInAs) {
      signedInAs.textContent = `signed in as ${session.user.email}`;
    }

    verifyAdmin(session.user);
  }

  async function verifyAdmin(user) {
    try {
      if (!api.fetchAdminProfile) {
        throw new Error('admin profile helper is not available');
      }

      const profile = await api.fetchAdminProfile(user.id, state.supabaseClient);

      if (!profile) {
        setAuthMessage('this account is not authorized yet. ask the owner to add you to the admins table.');
        const adminControls = document.getElementById('adminControls');
        if (adminControls) {
          adminControls.style.display = 'none';
        }
        return;
      }

      state.isAdmin = true;
      const authPanel = document.getElementById('authPanel');
      if (authPanel) {
        authPanel.classList.remove('alert-warning');
        authPanel.classList.add('alert-success');
      }
      setAuthMessage(`welcome ${profile.display_name || user.email}.`);
      await loadDashboard();
    } catch (error) {
      console.error('admin verification error', error);
      setAuthMessage('could not verify admin access. try signing out and back in.');
      const adminControls = document.getElementById('adminControls');
      if (adminControls) {
        adminControls.style.display = 'none';
      }
    }
  }

  async function loadDashboard() {
    if (!state.isAdmin) {
      return;
    }

    const adminControls = document.getElementById('adminControls');
    if (adminControls) {
      adminControls.style.display = 'block';
    }

    await Promise.all([
      loadCounts(),
      loadPendingReviews()
    ]);
  }

  async function loadCounts() {
    const pendingLabel = document.getElementById('pendingCount');
    const approvedLabel = document.getElementById('approvedCount');

    if (!api.countReviewsByStatus) {
      throw new Error('review counting helper is not available');
    }

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayIso = todayStart.toISOString();

    const [pendingCount, approvedCount] = await Promise.all([
      api.countReviewsByStatus('pending', {}, state.supabaseClient),
      api.countReviewsByStatus('approved', { since: todayIso }, state.supabaseClient)
    ]);

    if (pendingLabel) {
      pendingLabel.textContent = `${pendingCount} pending`;
    }
    if (approvedLabel) {
      approvedLabel.textContent = `${approvedCount} approved today`;
    }
  }

  async function loadPendingReviews() {
    const container = document.getElementById('pendingContainer');
    const emptyState = document.getElementById('emptyState');

    if (!container) {
      return;
    }

    container.innerHTML = '<div class="text-muted">loading pending reviews...</div>';

    if (!api.fetchReviewsByStatus) {
      container.innerHTML = '<div class="text-danger">review helpers are unavailable.</div>';
      return;
    }

    let data = [];
    try {
      data = await api.fetchReviewsByStatus('pending', state.supabaseClient);
    } catch (error) {
      console.error('failed to load pending reviews', error);
      container.innerHTML = '<div class="text-danger">failed to load pending reviews. try refreshing.</div>';
      return;
    }

    if (!data || data.length === 0) {
      container.innerHTML = '';
      if (emptyState) {
        emptyState.style.display = 'block';
      }
      return;
    }

    if (emptyState) {
      emptyState.style.display = 'none';
    }

    container.innerHTML = '';
    data.forEach((review) => {
      container.appendChild(buildReviewCard(review));
    });
  }

  function buildReviewCard(review) {
    const fountain = state.fountainById.get(review.fountain_id) || {};
    const card = document.createElement('div');
    card.className = 'review-card';

    const rows = [];
    rows.push(`<h5 class="mb-2">${escapeHtml(fountain.name || 'unknown fountain')}</h5>`);
    rows.push(`<div class="review-meta mb-2">${escapeHtml(fountain.id || '')} • ${escapeHtml(fountain.neighborhood || 'unknown area')}</div>`);
    rows.push(`<p class="mb-2">${escapeHtml(review.review_text || 'no additional notes provided.')}</p>`);

    const ratingPieces = [];
    if (review.rating !== null) { ratingPieces.push(`overall ${formatScore(review.rating)}`); }
    if (review.water_quality !== null) { ratingPieces.push(`water ${formatScore(review.water_quality)}`); }
    if (review.flow_pressure !== null) { ratingPieces.push(`flow ${formatScore(review.flow_pressure)}`); }
    if (review.temperature !== null) { ratingPieces.push(`temp ${formatScore(review.temperature)}`); }
    if (review.cleanliness !== null) { ratingPieces.push(`drainage ${formatScore(review.cleanliness)}`); }
    if (review.accessibility !== null) { ratingPieces.push(`access ${formatScore(review.accessibility)}`); }

    if (ratingPieces.length > 0) {
      rows.push(`<div class="mb-2"><strong>scores:</strong> ${ratingPieces.join(' • ')}</div>`);
    }

    const submitted = new Date(review.created_at).toLocaleString();
    const visitDate = review.visit_date ? new Date(review.visit_date).toLocaleDateString() : 'not provided';
    rows.push(`<div class="review-meta mb-2">submitted ${escapeHtml(submitted)} • visited ${escapeHtml(visitDate)}</div>`);

    const reviewerLine = [`by ${escapeHtml(review.reviewer_name || 'anonymous user')}`];
    if (review.reviewer_email) {
      reviewerLine.push(`(${escapeHtml(review.reviewer_email)})`);
    }
    reviewerLine.push(review.author_type === 'admin' ? 'admin review' : 'public submission');
    rows.push(`<div class="review-meta mb-3">${reviewerLine.join(' • ')}</div>`);

    if (review.instagram_url) {
      rows.push(`<div class="mb-3"><a href="${escapeHtml(review.instagram_url)}" target="_blank">view instagram post</a></div>`);
    }

    card.innerHTML = rows.join('');

    const actionsRow = document.createElement('div');
    actionsRow.className = 'd-flex gap-2';
    const approveButton = document.createElement('button');
    approveButton.className = 'btn btn-success btn-sm';
    approveButton.textContent = 'approve';
    approveButton.addEventListener('click', () => updateReviewStatus(review.id, 'approved', approveButton));

    const rejectButton = document.createElement('button');
    rejectButton.className = 'btn btn-outline-danger btn-sm';
    rejectButton.textContent = 'reject';
    rejectButton.addEventListener('click', () => updateReviewStatus(review.id, 'rejected', rejectButton));

    actionsRow.appendChild(approveButton);
    actionsRow.appendChild(rejectButton);
    card.appendChild(actionsRow);

    return card;
  }

  async function updateReviewStatus(reviewId, status, button) {
    if (button) {
      button.disabled = true;
      button.textContent = status === 'approved' ? 'approving...' : 'rejecting...';
    }

    if (!api.updateReviewStatus) {
      throw new Error('review update helper is not available');
    }

    const payload = status === 'approved'
      ? { reviewed_at: new Date().toISOString() }
      : {};

    try {
      await api.updateReviewStatus(reviewId, status, payload, state.supabaseClient);
    } catch (error) {
      if (button) {
        button.disabled = false;
        button.textContent = status === 'approved' ? 'approve' : 'reject';
      }
      console.error('failed to update review status', error);
      alert(`failed to update review: ${error.message}`);
      return;
    }

    if (button) {
      button.disabled = false;
      button.textContent = status === 'approved' ? 'approve' : 'reject';
    }

    if (typeof ui.toast === 'function') {
      const message = status === 'approved' ? 'review approved and published.' : 'review rejected.';
      const toastType = status === 'approved' ? 'success' : 'warning';
      ui.toast(message, toastType);
    }

    await loadDashboard();
  }

  function setAuthMessage(message) {
    const authMessage = document.getElementById('authMessage');
    if (authMessage) {
      authMessage.textContent = message;
    }
  }

  function disableLogin() {
    const loginForm = document.getElementById('loginForm');
    if (!loginForm) {
      return;
    }
    Array.from(loginForm.elements).forEach((element) => {
      element.setAttribute('disabled', 'disabled');
    });
  }

  function escapeHtml(value) {
    if (value === null || value === undefined) {
      return '';
    }
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function formatScore(value) {
    return `${Number.parseFloat(value).toFixed(1)}/10`;
  }
})();
