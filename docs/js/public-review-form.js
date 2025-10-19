'use strict';

(function () {
  const config = window.APP_CONFIG || {};
  const api = window.AppApi || {};
  const ui = window.AppUI || {};
  const state = {
    map: null,
    fountains: [],
    markers: [],
    markerById: new Map(),
    selectedMarker: null,
    supabaseClient: null
  };

  document.addEventListener('DOMContentLoaded', init);

  /**
   * bootstraps the map, data loading, and form handling once the page is ready.
   */
  async function init() {
    if (typeof api.getClient === 'function') {
      state.supabaseClient = api.getClient();
    }

    setDefaultVisitDate();
    setupClearButton();
    setupSearchHandlers();
    setupFormSubmission();

    try {
      await setupMap();
      await loadFountains();
    } catch (error) {
      console.error('failed to load fountain data', error);
      showAlert('unable to load fountains right now. please refresh the page in a moment.', 'danger');
    }
  }

  function setDefaultVisitDate() {
    const visitInput = document.getElementById('visitDate');
    if (visitInput) {
      visitInput.value = new Date().toISOString().split('T')[0];
    }
  }

  function setupClearButton() {
    const clearButton = document.getElementById('clearSelectionBtn');
    if (!clearButton) {
      return;
    }
    clearButton.addEventListener('click', () => {
      clearSelection();
    });
  }

  function setupSearchHandlers() {
    const searchInput = document.getElementById('fountainIdInput');
    if (!searchInput) {
      return;
    }

    searchInput.addEventListener('input', handleSearchInput);
    searchInput.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        chooseFirstSuggestion();
      }
    });

    document.addEventListener('click', (event) => {
      if (!event.target.closest('.fountain-search')) {
        hideSuggestions();
      }
    });
  }

  function setupFormSubmission() {
    const form = document.getElementById('reviewForm');
    if (!form) {
      return;
    }

    form.addEventListener('submit', async (event) => {
      event.preventDefault();

      const data = collectFormData();
      if (!validateForm(data)) {
        return;
      }

      if (!api.hasCredentials || !api.hasCredentials()) {
        showAlert('supabase is not configured. update config.js with your supabase url and anon key to enable submissions.', 'danger');
        return;
      }

      if (!state.supabaseClient && typeof api.getClient === 'function') {
        state.supabaseClient = api.getClient();
      }

      if (!state.supabaseClient) {
        showAlert('could not create supabase client. double-check your configuration values.', 'danger');
        return;
      }

      try {
        await submitReview(data);
        showAlert('thanks for sharing a review! it will appear on the map after moderation.', 'success');
        if (typeof ui.toast === 'function') {
          ui.toast('thanks for sharing a review! pending approval.', 'success');
        }
        resetForm();
      } catch (error) {
        console.error('supabase insert failed', error);
        showAlert('something went wrong while saving your review. please try again.', 'danger');
      }
    });
  }

  async function setupMap() {
    const mapElement = document.getElementById('fountainMap');
    if (!mapElement) {
      throw new Error('missing map container');
    }

    state.map = L.map('fountainMap').setView(config.MAP_CENTER || [49.251, -123.060], config.MAP_ZOOM || 11);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(state.map);
  }

  async function loadFountains() {
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
        color: '#007bff',
        fillColor: '#007bff',
        fillOpacity: 0.7,
        weight: 2
      }).addTo(state.map);

      marker.on('click', () => {
        selectFountain(props, marker);
      });

      marker.bindPopup([
        `<strong>${escapeHtml(props.name || 'Unnamed Fountain')}</strong>`,
        `<small>ID: ${escapeHtml(props.id || 'N/A')}</small>`,
        props.neighborhood ? `<small>${escapeHtml(props.neighborhood)}</small>` : ''
      ].join('<br>'));

      state.markerById.set(props.id, marker);
      state.markers.push(marker);
    });
  }

  function handleSearchInput(event) {
    const query = event.target.value.trim().toLowerCase();
    const suggestionsDiv = document.getElementById('fountainSuggestions');

    if (!suggestionsDiv) {
      return;
    }

    if (query.length === 0) {
      hideSuggestions();
      return;
    }

    const matches = state.fountains
      .map((feature) => feature.properties || {})
      .filter((props) => {
        const id = (props.id || '').toLowerCase();
        const name = (props.name || '').toLowerCase();
        return id.includes(query) || name.includes(query);
      })
      .slice(0, 8);

    if (matches.length === 0) {
      suggestionsDiv.innerHTML = '<div class="fountain-suggestion">no fountains found</div>';
      suggestionsDiv.style.display = 'block';
      return;
    }

    suggestionsDiv.innerHTML = matches.map((props) => {
      return [
        `<div class="fountain-suggestion" data-fountain-id="${escapeHtml(props.id || '')}">`,
        `<strong>${escapeHtml(props.id || 'N/A')}</strong> - ${escapeHtml(props.name || 'Unnamed Fountain')}`,
        props.neighborhood ? `<br><small class="text-muted">${escapeHtml(props.neighborhood)}</small>` : '',
        '</div>'
      ].join('');
    }).join('');

    Array.from(suggestionsDiv.children).forEach((child) => {
      child.addEventListener('click', () => {
        const fountainId = child.getAttribute('data-fountain-id');
        selectFountainById(fountainId);
      });
    });

    suggestionsDiv.style.display = 'block';
  }

  function chooseFirstSuggestion() {
    const suggestionsDiv = document.getElementById('fountainSuggestions');
    if (!suggestionsDiv) {
      return;
    }
    const first = suggestionsDiv.querySelector('.fountain-suggestion');
    if (first && first.dataset.fountainId) {
      selectFountainById(first.dataset.fountainId);
    }
  }

  function hideSuggestions() {
    const suggestionsDiv = document.getElementById('fountainSuggestions');
    if (suggestionsDiv) {
      suggestionsDiv.style.display = 'none';
    }
  }

  function selectFountainById(fountainId) {
    if (!fountainId) {
      return;
    }
    const feature = state.fountains.find((item) => {
      const props = item.properties || {};
      return props.id === fountainId;
    });
    if (!feature) {
      return;
    }

    const marker = state.markerById.get(fountainId);
    if (marker) {
      const latlng = marker.getLatLng();
      state.map.setView(latlng, 16);
    }

    selectFountain(feature.properties || {}, marker || null);
  }

  function selectFountain(props, marker) {
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({
        fillColor: '#007bff',
        color: '#007bff',
        radius: 8
      });
    }

    if (marker) {
      marker.setStyle({
        fillColor: '#28a745',
        color: '#28a745',
        radius: 12
      });
      state.selectedMarker = marker;
    }

    setFieldValue('fountainId', props.id || '');
    setFieldValue('fountainName', props.name || '');
    setFieldValue('fountainSupabaseId', props.supabase_id || '');
    setFieldValue('fountainIdInput', props.id || '');

    const infoBox = document.getElementById('selectedFountainInfo');
    if (infoBox) {
      infoBox.style.display = 'block';
    }
    setTextContent('selectedFountainId', props.id || 'N/A');
    setTextContent('selectedFountainName', props.name || 'Unnamed Fountain');
    setTextContent('selectedFountainLocation', props.location || props.address || 'N/A');
    setTextContent('selectedFountainNeighborhood', props.neighborhood || 'N/A');

    const clearButton = document.getElementById('clearSelectionBtn');
    if (clearButton) {
      clearButton.style.display = 'inline-block';
    }

    hideSuggestions();
  }

  function clearSelection() {
    if (state.selectedMarker) {
      state.selectedMarker.setStyle({
        fillColor: '#007bff',
        color: '#007bff',
        radius: 8
      });
      state.selectedMarker = null;
    }

    setFieldValue('fountainId', '');
    setFieldValue('fountainName', '');
    setFieldValue('fountainSupabaseId', '');
    setFieldValue('fountainIdInput', '');

    const infoBox = document.getElementById('selectedFountainInfo');
    if (infoBox) {
      infoBox.style.display = 'none';
    }

    const clearButton = document.getElementById('clearSelectionBtn');
    if (clearButton) {
      clearButton.style.display = 'none';
    }

    hideSuggestions();
    if (state.map) {
      state.map.setView(config.MAP_CENTER || [49.251, -123.060], config.MAP_ZOOM || 11);
    }
  }

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
      waterQuality: formData.get('waterQuality'),
      flowPressure: formData.get('flowPressure'),
      temperature: formData.get('temperature'),
      cleanliness: formData.get('cleanliness'),
      accessibility: formData.get('accessibility'),
      additionalNotes: document.getElementById('additionalNotes').value.trim()
    };
  }

  function validateForm(data) {
    if (!data.fountainId || !data.supabaseFountainId) {
      showAlert('please pick a fountain from the list before submitting your review.', 'danger');
      return false;
    }
    if (!data.reviewerName) {
      showAlert('please add your name so we can attribute the review.', 'danger');
      return false;
    }
    if (!data.visitDate) {
      showAlert('please include the date you visited the fountain.', 'danger');
      return false;
    }
    if (!data.overallRating) {
      showAlert('please provide an overall rating on the 1-10 scale.', 'danger');
      return false;
    }
    return true;
  }

  async function submitReview(data) {
    const payload = {
      fountain_id: data.supabaseFountainId,
      status: 'pending',
      author_type: 'public',
      reviewer_name: data.reviewerName,
      reviewer_email: data.reviewerEmail || null,
      visit_date: data.visitDate || null,
      rating: toNumeric(data.overallRating),
      water_quality: toNumeric(data.waterQuality),
      flow_pressure: toNumeric(data.flowPressure),
      temperature: toNumeric(data.temperature),
      cleanliness: toNumeric(data.cleanliness),
      accessibility: toNumeric(data.accessibility),
      review_text: data.additionalNotes || null
    };

    if (!api.insertPublicReview) {
      throw new Error('supabase api helpers are not available');
    }

    await api.insertPublicReview(payload, state.supabaseClient);
  }

  function resetForm() {
    const form = document.getElementById('reviewForm');
    if (form) {
      form.reset();
    }
    clearSelection();
    setDefaultVisitDate();
  }

  function setFieldValue(id, value) {
    const field = document.getElementById(id);
    if (field) {
      field.value = value;
    }
  }

  function setTextContent(id, value) {
    const element = document.getElementById(id);
    if (element) {
      element.textContent = value;
    }
  }

  function toNumeric(value) {
    if (value === undefined || value === null || value === '') {
      return null;
    }
    const number = Number.parseFloat(value);
    return Number.isFinite(number) ? number : null;
  }

  function showAlert(message, type) {
    const container = document.getElementById('alertContainer');
    if (!container) {
      return;
    }
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show mt-3`;
    alertDiv.innerHTML = [
      escapeHtml(message),
      '<button type="button" class="btn-close" data-bs-dismiss="alert"></button>'
    ].join('');
    container.appendChild(alertDiv);
    setTimeout(() => {
      if (alertDiv.parentNode) {
        alertDiv.remove();
      }
    }, 10000);
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
