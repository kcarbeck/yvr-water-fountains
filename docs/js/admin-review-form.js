'use strict';

(function () {
  const config = window.APP_CONFIG || {};
  const api = window.AppApi || {};
  const ui = window.AppUI || {};
  const state = {
    supabaseClient: null,
    fountains: [],
    markers: [],
    markerById: new Map(),
    map: null,
    selectedFountain: null,
    selectedMarker: null,
    isAdmin: false
  };

  document.addEventListener('DOMContentLoaded', init);

  /**
   * initializes auth, map, and form behavior when the admin page loads.
   */
  async function init() {
    hideAdminContent();
    setDefaultVisitDate();

    if (!api.hasCredentials || !api.hasCredentials()) {
      showAuthMessage('supabase configuration missing. add your project url and anon key to config.js.');
      disableLoginForm();
      return;
    }

    state.supabaseClient = typeof api.getClient === 'function'
      ? api.getClient()
      : null;

    if (!state.supabaseClient) {
      showAuthMessage('supabase client failed to initialize. double-check your configuration values.');
      disableLoginForm();
      return;
    }

    setupAuthHandlers();
    setupSearchInteractions();
    setupReviewForm();

    try {
      await setupMap();
      await loadFountains();
    } catch (error) {
      console.error('failed to load fountains for admin form', error);
      showFormAlert('could not load fountain data. refresh the page and try again.', 'danger');
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
        const email = document.getElementById('adminEmail').value.trim();
        const password = document.getElementById('adminPassword').value;

        if (!email || !password) {
          showAuthMessage('please provide both email and password.');
          return;
        }

        try {
          const { error } = await state.supabaseClient.auth.signInWithPassword({ email, password });
          if (error) {
            showAuthMessage(`sign in failed: ${error.message}`);
            return;
          }
          showAuthMessage('sign in succeeded. verifying admin access...');
        } catch (error) {
          console.error('supabase sign in failed', error);
          showAuthMessage('sign in failed due to a network issue. try again.');
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

  function setupSearchInteractions() {
    const searchInput = document.getElementById('fountainIdInput');
    const searchButton = document.getElementById('searchButton');

    if (searchInput) {
      searchInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
          event.preventDefault();
          focusFountain(searchInput.value.trim());
        }
      });
    }

    if (searchButton) {
      searchButton.addEventListener('click', (event) => {
        event.preventDefault();
        focusFountain((searchInput && searchInput.value.trim()) || '');
      });
    }
  }

  function setupReviewForm() {
    const form = document.getElementById('adminReviewForm');
    if (!form) {
      return;
    }

    form.addEventListener('submit', async (event) => {
      event.preventDefault();

      if (!state.isAdmin) {
        showFormAlert('sign in with an admin account before submitting a review.', 'danger');
        return;
      }

      if (!state.selectedFountain) {
        showFormAlert('select a fountain from the map first.', 'danger');
        return;
      }

      const data = collectFormData();
      const validationError = validateAdminForm(data);
      if (validationError) {
        showFormAlert(validationError, 'danger');
        return;
      }

      try {
        await submitAdminReview(data);
        showFormAlert('review saved and published to the map.', 'success');
        resetForm();
      } catch (error) {
        console.error('failed to insert admin review', error);
        showFormAlert(error.message || 'database error while saving the review.', 'danger');
      }
    });
  }

  async function setupMap() {
    state.map = L.map('map').setView(config.MAP_CENTER || [49.251, -123.060], config.MAP_ZOOM || 11);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(state.map);
  }

  async function loadFountains() {
    const loadingMessage = document.getElementById('loadingMessage');
    const reviewForm = document.getElementById('reviewForm');

    const geojson = await FountainData.fetchGeoData();
    state.fountains = Array.isArray(geojson.features) ? geojson.features : [];

    state.markerById.clear();
    state.markers.forEach((marker) => marker.remove());
    state.markers = [];

    state.fountains.forEach((feature) => {
      const props = feature.properties || {};
      const coordinates = feature.geometry && feature.geometry.coordinates ? feature.geometry.coordinates : null;
      if (!Array.isArray(coordinates) || coordinates.length < 2) {
        return;
      }

      const latlng = [coordinates[1], coordinates[0]];
      const marker = L.circleMarker(latlng, {
        radius: 8,
        color: '#dc3545',
        fillColor: '#dc3545',
        fillOpacity: 0.7,
        weight: 2
      }).addTo(state.map);

      marker.on('click', () => {
        selectFountain(feature.properties || {}, marker);
      });

      marker.bindPopup([
        `<strong>${escapeHtml(props.name || 'Unnamed Fountain')}</strong>`,
        `<small>ID: ${escapeHtml(props.id || 'N/A')}</small>`,
        props.neighborhood ? `<small>${escapeHtml(props.neighborhood)}</small>` : ''
      ].join('<br>'));

      state.markerById.set(props.id, marker);
      state.markers.push(marker);
    });

    if (loadingMessage) {
      loadingMessage.style.display = 'none';
    }
    if (reviewForm) {
      reviewForm.style.display = state.isAdmin ? 'block' : 'none';
    }
  }

  function applySession(session) {
    const loginForm = document.getElementById('loginForm');
    const logoutButton = document.getElementById('logoutButton');
    const authPanel = document.getElementById('authPanel');

    state.isAdmin = false;

    if (!session) {
      showAuthMessage('sign in with your supabase admin email to unlock this form.');
      if (loginForm) {
        loginForm.style.display = 'block';
      }
      if (logoutButton) {
        logoutButton.style.display = 'none';
      }
      if (authPanel) {
        authPanel.classList.remove('alert-success');
        authPanel.classList.add('alert-warning');
      }
      hideAdminContent();
      return;
    }

    if (loginForm) {
      loginForm.style.display = 'none';
    }
    if (logoutButton) {
      logoutButton.style.display = 'inline-block';
    }

    verifyAdminAccess(session.user);
  }

  async function verifyAdminAccess(user) {
    try {
      if (!api.fetchAdminProfile) {
        throw new Error('admin profile helper is not available');
      }

      const profile = await api.fetchAdminProfile(user.id, state.supabaseClient);

      if (!profile) {
        showAuthMessage('your account is signed in but not yet authorized. ask the owner to add you to the admins table.');
        hideAdminContent();
        return;
      }

      state.isAdmin = true;
      showAuthMessage(`signed in as ${escapeHtml(profile.display_name || user.email)}.`);
      const authPanel = document.getElementById('authPanel');
      if (authPanel) {
        authPanel.classList.remove('alert-warning');
        authPanel.classList.add('alert-success');
      }
      showAdminContent();
    } catch (error) {
      console.error('admin verification failed', error);
      showAuthMessage('could not verify admin permissions. try signing out and back in.');
      hideAdminContent();
    }
  }

  function showAdminContent() {
    const wrapper = document.getElementById('adminFormContent');
    const reviewForm = document.getElementById('reviewForm');
    if (wrapper) {
      wrapper.style.display = 'block';
    }
    if (reviewForm) {
      reviewForm.style.display = 'block';
    }
  }

  function hideAdminContent() {
    const wrapper = document.getElementById('adminFormContent');
    const reviewForm = document.getElementById('reviewForm');
    if (wrapper) {
      wrapper.style.display = 'none';
    }
    if (reviewForm) {
      reviewForm.style.display = 'none';
    }
  }

  function disableLoginForm() {
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
      Array.from(loginForm.elements).forEach((element) => {
        element.setAttribute('disabled', 'disabled');
      });
    }
  }

  function showAuthMessage(message) {
    const authAlert = document.getElementById('authAlert');
    if (!authAlert) {
      return;
    }
    authAlert.innerText = message;
  }

  function selectFountain(props, marker) {
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({
        fillColor: '#dc3545',
        color: '#dc3545',
        radius: 8
      });
    }

    if (marker) {
      marker.setStyle({
        fillColor: '#198754',
        color: '#198754',
        radius: 12
      });
      state.selectedMarker = marker;
    }

    state.selectedFountain = props;
    updateFountainDetails(props);
  }

  function focusFountain(query) {
    if (!query) {
      return;
    }
    const lowerQuery = query.toLowerCase();
    const feature = state.fountains.find((item) => {
      const props = item.properties || {};
      const id = (props.id || '').toLowerCase();
      const name = (props.name || '').toLowerCase();
      return id.includes(lowerQuery) || name.includes(lowerQuery);
    });

    if (!feature) {
      showFormAlert('no matching fountain found. try another id or name fragment.', 'warning');
      return;
    }

    const marker = state.markerById.get(feature.properties.id);
    if (marker) {
      const latlng = marker.getLatLng();
      state.map.setView(latlng, 16);
    }
    selectFountain(feature.properties || {}, marker || null);
  }

  function updateFountainDetails(props) {
    const container = document.getElementById('fountainInfo');
    const details = document.getElementById('fountainDetails');
    if (!container || !details) {
      return;
    }

    container.style.display = 'block';
    const rows = [
      `<strong>ID:</strong> ${escapeHtml(props.id || 'N/A')}`,
      `<strong>Name:</strong> ${escapeHtml(props.name || 'Unnamed Fountain')}`,
      `<strong>Location:</strong> ${escapeHtml(props.location || props.address || 'N/A')}`,
      `<strong>Neighbourhood:</strong> ${escapeHtml(props.neighborhood || 'N/A')}`,
      `<strong>City:</strong> ${escapeHtml(props.city_name || 'Vancouver')}`
    ];
    details.innerHTML = rows.map((row) => `<p>${row}</p>`).join('');
  }

  function collectFormData() {
    return {
      instagramUrl: document.getElementById('instagramUrl').value.trim(),
      instagramCaption: document.getElementById('instagramCaption').value.trim(),
      overallRating: document.getElementById('overallRating').value,
      waterQuality: document.getElementById('waterQuality').value,
      flowPressure: document.getElementById('flowPressure').value,
      temperature: document.getElementById('temperature').value,
      drainage: document.getElementById('drainage').value,
      accessibility: document.getElementById('accessibility').value,
      reviewNotes: document.getElementById('reviewNotes').value.trim(),
      visitDate: document.getElementById('visitDate').value
    };
  }

  function validateAdminForm(data) {
    if (!data.instagramUrl) {
      return 'add the instagram post url so visitors can see the source.';
    }
    if (!data.overallRating) {
      return 'provide an overall rating on the 1-10 scale.';
    }
    if (!data.waterQuality || !data.flowPressure || !data.temperature || !data.drainage || !data.accessibility) {
      return 'fill in all rating categories before publishing the review.';
    }
    if (!data.visitDate) {
      return 'include the visit date for proper context.';
    }
    return null;
  }

  async function submitAdminReview(data) {
    const fountainId = state.selectedFountain ? state.selectedFountain.supabase_id : null;
    if (!fountainId) {
      throw new Error('missing fountain identifier. try reselecting the fountain.');
    }

    const payload = {
      fountain_id: fountainId,
      author_type: 'admin',
      status: 'approved',
      rating: toNumeric(data.overallRating),
      water_quality: toNumeric(data.waterQuality),
      flow_pressure: toNumeric(data.flowPressure),
      temperature: toNumeric(data.temperature),
      cleanliness: toNumeric(data.drainage),
      accessibility: toNumeric(data.accessibility),
      review_text: data.reviewNotes || null,
      instagram_url: data.instagramUrl,
      instagram_caption: data.instagramCaption || null,
      instagram_image_url: buildInstagramImageUrl(data.instagramUrl),
      visit_date: data.visitDate || null,
      reviewed_at: data.visitDate ? `${data.visitDate}T12:00:00Z` : new Date().toISOString()
    };

    if (!api.insertAdminReview) {
      throw new Error('supabase api helpers are not available');
    }

    await api.insertAdminReview(payload, state.supabaseClient);
    if (typeof ui.toast === 'function') {
      ui.toast('admin review published to the map.', 'success');
    }
  }

  function resetForm() {
    const form = document.getElementById('adminReviewForm');
    if (form) {
      form.reset();
    }
    state.selectedFountain = null;
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({
        fillColor: '#dc3545',
        color: '#dc3545',
        radius: 8
      });
      state.selectedMarker = null;
    }
    const info = document.getElementById('fountainInfo');
    if (info) {
      info.style.display = 'none';
    }
    setDefaultVisitDate();
  }

  function setDefaultVisitDate() {
    const visitDate = document.getElementById('visitDate');
    if (visitDate) {
      visitDate.value = new Date().toISOString().split('T')[0];
    }
  }

  function showFormAlert(message, type) {
    const container = document.getElementById('alertContainer');
    if (!container) {
      return;
    }
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = [
      escapeHtml(message),
      '<button type="button" class="btn-close" data-bs-dismiss="alert"></button>'
    ].join('');
    container.appendChild(alertDiv);
    if (type === 'success') {
      setTimeout(() => {
        if (alertDiv.parentNode) {
          alertDiv.remove();
        }
      }, 5000);
    }
  }

  function toNumeric(value) {
    if (value === undefined || value === null || value === '') {
      return null;
    }
    const number = Number.parseFloat(value);
    return Number.isFinite(number) ? number : null;
  }

  function buildInstagramImageUrl(url) {
    if (!url) {
      return null;
    }
    const match = url.match(/\/p\/([^\/]+)\//);
    if (!match) {
      return null;
    }
    const postId = match[1];
    return `https://instagram.com/p/${postId}/media/?size=l`;
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
})();
