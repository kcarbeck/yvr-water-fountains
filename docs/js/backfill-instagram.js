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
