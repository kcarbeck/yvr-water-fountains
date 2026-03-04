'use strict';

(function () {
  const config = window.APP_CONFIG || {};
  const state = {
    map: null,
    markerById: new Map(),
    fountains: [],
    currentFountain: null
  };

  const dom = {
    bottomSheet: null,
    bottomSheetContent: null,
    overlay: null,
    bottomSheetClose: null,
    locateButton: null,
    adminButton: null
  };

  window.showFountainDetails = showFountainDetails;
  window.showAllReviews = showAllReviews;

  window.addEventListener('DOMContentLoaded', init);

  /**
   * prepares core references and starts the map rendering flow.
   */
  async function init() {
    cacheDom();
    state.map = buildMap();
    applyBaseLayer();
    applyInitialView();
    registerResizeHandling();
    registerTouchShortcuts();
    registerLocateMe();
    registerAdminAccess();

    try {
      const data = await FountainData.fetchGeoData();
      state.fountains = data.features || [];
      placeFountainsOnMap(data);
      focusFromHash();
    } catch (error) {
      handleLoadError(error);
    }
  }

  /**
   * stores frequently accessed dom elements for reuse.
   */
  function cacheDom() {
    dom.bottomSheet = document.getElementById('bottom-sheet');
    dom.bottomSheetContent = document.getElementById('bottom-sheet-content');
    dom.overlay = document.getElementById('overlay');
    dom.bottomSheetClose = document.getElementById('bottom-sheet-close');
    dom.locateButton = document.getElementById('locate-me');
    dom.adminButton = document.getElementById('admin-access');

    if (dom.bottomSheetClose) {
      dom.bottomSheetClose.addEventListener('click', hideBottomSheet);
    }

    if (dom.overlay) {
      dom.overlay.addEventListener('click', hideBottomSheet);
    }
  }

  /**
   * creates the leaflet map instance.
   */
  function buildMap() {
    return L.map('map');
  }

  /**
   * applies the base tile layer to the map.
   */
  function applyBaseLayer() {
    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> © <a href="https://carto.com/">CARTO</a>',
      subdomains: 'abcd',
      maxZoom: 20
    }).addTo(state.map);
  }

  /**
   * sets a viewport appropriate for the device size.
   */
  function applyInitialView() {
    if (isMobile()) {
      state.map.setView(config.MAP_CENTER, (config.MAP_ZOOM || 0) - 1);
    } else {
      state.map.setView(config.MAP_CENTER, config.MAP_ZOOM);
    }
  }

  /**
   * installs listeners to keep the map responsive.
   */
  function registerResizeHandling() {
    const throttledResize = throttle(() => {
      state.map.invalidateSize();
      if (window.innerWidth > 768 && dom.bottomSheet && dom.bottomSheet.classList.contains('active')) {
        hideBottomSheet();
      }
    }, 150);

    window.addEventListener('resize', throttledResize);

    window.addEventListener('orientationchange', () => {
      setTimeout(() => {
        state.map.invalidateSize();
        if (isMobile()) {
          applyInitialView();
        }
      }, 100);
    });
  }

  /**
   * improves touch interactions for the bottom sheet.
   */
  function registerTouchShortcuts() {
    if (!isTouchDevice() || !dom.bottomSheet) {
      return;
    }

    dom.bottomSheet.addEventListener('touchstart', (event) => {
      dom.bottomSheet.startY = event.touches[0].pageY;
    }, { passive: true });

    dom.bottomSheet.addEventListener('touchmove', (event) => {
      if (dom.bottomSheet.scrollTop === 0 && event.touches[0].pageY > dom.bottomSheet.startY) {
        event.preventDefault();
      }
    }, { passive: false });

    let swipeStartY = 0;
    dom.bottomSheet.addEventListener('touchstart', (event) => {
      swipeStartY = event.touches[0].clientY;
    }, { passive: true });

    dom.bottomSheet.addEventListener('touchend', (event) => {
      const swipeEndY = event.changedTouches[0].clientY;
      const diffY = swipeStartY - swipeEndY;

      if (diffY < -100 && dom.bottomSheet.scrollTop < 20) {
        hideBottomSheet();
      }
    }, { passive: true });

    document.body.classList.add('touch-device');
  }

  /**
   * wires the geolocation helper button.
   */
  function registerLocateMe() {
    if (!dom.locateButton) {
      return;
    }

    dom.locateButton.addEventListener('click', (event) => {
      event.preventDefault();
      if (!navigator.geolocation) {
        alert('Geolocation is not supported by this browser');
        return;
      }

      navigator.geolocation.getCurrentPosition((position) => {
        const { latitude, longitude } = position.coords;
        state.map.setView([latitude, longitude], 15);
      }, () => {
        alert('Unable to get your location');
      });
    });
  }

  /**
   * wires the admin access icon to the password check flow.
   */
  function registerAdminAccess() {
    if (!dom.adminButton) {
      return;
    }

    dom.adminButton.addEventListener('click', async (event) => {
      event.preventDefault();
      const password = prompt('Enter admin password:');

      if (!password) {
        return;
      }

      const isValid = await verifyAdminPassword(password);
      if (isValid) {
        showAdminPanel();
      } else if (password !== null) {
        alert('Incorrect password');
      }
    });
  }

  /**
   * returns marker styling based on review status.
   * green = admin reviewed, orange = community reviewed, blue = unreviewed.
   */
  function markerStyle(props) {
    const adminCount = props.admin_review_count || 0;
    const totalCount = props.rating_count || 0;
    let color;

    if (adminCount > 0) {
      color = '#c8ff00';
    } else if (totalCount > 0) {
      color = '#ff69b4';
    } else {
      color = '#c5a3ff';
    }

    return {
      radius: 6,
      color: '#1a1a2e',
      fillColor: color,
      fillOpacity: 0.85,
      weight: 1.5
    };
  }

  /**
   * draws markers using the geojson payload.
   */
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

  /**
   * adds click and popup behavior for each fountain marker.
   */
  function attachFountainBehavior(feature, layer) {
    const properties = feature.properties || {};
    const latestInstagramPost = pickLatestInstagramPost(properties);
    const latestPhotoUrl = latestInstagramPost ? getInstagramPhotoUrl(latestInstagramPost.url) : null;
    const adminReview = isAdminReview(properties);

    if (isMobile()) {
      layer.on('click', () => {
        showBottomSheet(properties, latestInstagramPost, latestPhotoUrl, adminReview);
      });
    } else {
      const popupContent = buildPopupContent(properties, latestInstagramPost, latestPhotoUrl, adminReview);
      layer.bindPopup(popupContent);
    }

    if (properties.id) {
      state.markerById.set(properties.id, layer);
    }
  }

  /**
   * ensures a location linked via hash is focused after load.
   */
  function focusFromHash() {
    const hash = window.location.hash.replace('#', '');
    if (!hash) {
      return;
    }

    const marker = state.markerById.get(hash);
    if (!marker) {
      return;
    }

    state.map.setView(marker.getLatLng(), 16, { animate: true });

    if (isMobile()) {
      const fountain = state.fountains.find((feature) => (feature.properties || {}).id === hash);
      if (fountain) {
        const properties = fountain.properties || {};
        const latestInstagramPost = pickLatestInstagramPost(properties);
        const latestPhotoUrl = latestInstagramPost ? getInstagramPhotoUrl(latestInstagramPost.url) : null;
        const adminReview = isAdminReview(properties);
        showBottomSheet(properties, latestInstagramPost, latestPhotoUrl, adminReview);
      }
    } else {
      marker.openPopup();
    }
  }

  /**
   * informs the visitor that fountain data failed to load.
   */
  function handleLoadError(error) {
    console.error('failed to load fountain data', error);
    alert('Failed to load fountain data. Check console for details.');
  }

  /**
   * shows the admin shortcut panel when credentials succeed.
   */
  function showAdminPanel() {
    const panel = document.createElement('div');
    panel.style.cssText = [
      'position: fixed',
      'top: 50%','left: 50%',
      'transform: translate(-50%, -50%)',
      'background: white',
      'padding: 20px',
      'border-radius: 10px',
      'box-shadow: 0 4px 20px rgba(0,0,0,0.3)',
      'z-index: 3000',
      'text-align: center'
    ].join(';');

    panel.innerHTML = [
      '<h3>🔧 Admin Panel</h3>',
      '<div style="margin: 15px 0;">',
      '<a href="admin_review_form.html" style="display: block; margin: 10px 0; padding: 10px; background: #007bff; color: white; text-decoration: none; border-radius: 5px;">📝 Admin Review Form</a>',
      '<a href="moderation_dashboard.html" style="display: block; margin: 10px 0; padding: 10px; background: #007bff; color: white; text-decoration: none; border-radius: 5px;">🛡️ Moderation Dashboard</a>',
      '</div>',
      '<button style="background: #dc3545; color: white; border: none; padding: 8px 16px; border-radius: 5px; cursor: pointer;">Close</button>'
    ].join('');

    panel.querySelector('button').addEventListener('click', () => {
      panel.remove();
    });

    document.body.appendChild(panel);
  }

  /**
   * checks the supplied admin password by delegating to the serverless function.
   */
  async function verifyAdminPassword(password) {
    const endpoint = config.API_ENDPOINT || '/.netlify/functions/submit-review';
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          reviewType: 'admin',
          reviewData: {
            adminPassword: password,
            fountainId: 'password_check',
            overallRating: 1,
            waterQuality: 1,
            flowPressure: 1,
            temperature: 1,
            drainage: 1,
            accessibility: 1,
            visitDate: '2024-01-01',
            notes: 'password verification test'
          }
        })
      });

      if (response.status === 500) {
        const result = await response.json();
        if (result.message && result.message.includes('Fountain not found')) {
          return true;
        }
        if (result.message && result.message.includes('Invalid admin password')) {
          return false;
        }
      }

      return response.ok;
    } catch (error) {
      console.error('password verification failed', error);
      return false;
    }
  }

  /**
   * renders the popup markup for desktop visitors.
   */
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

  /**
   * renders the bottom sheet markup for mobile visitors.
   */
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

  /**
   * constructs the shared instagram preview snippet.
   */
  function buildInstagramPreview(post, photoUrl) {
    const pieces = [];
    pieces.push('<div class="instagram-preview-container">');
    pieces.push('<div class="instagram-preview-text">');
    pieces.push(`<a href="${post.url}" target="_blank" class="popup-clickable">@yvrwaterfountains post</a>`);
    if (post.date_posted) {
      pieces.push(`<br><small>${formatDate(post.date_posted)}</small>`);
    }
    pieces.push('</div>');
    if (photoUrl) {
      pieces.push(`<img src="${photoUrl}" alt="Instagram photo" class="instagram-photo-preview" onclick="window.open('${post.url}', '_blank')">`);
    }
    pieces.push('</div>');
    return pieces.join('');
  }

  /**
   * builds a labeled detail row for popups and sheets.
   */
  function buildInfoRow(context, label, value) {
    const baseClass = context === 'popup' ? 'popup' : 'bottom-sheet';
    return '<div class="' + baseClass + '-info"><span class="' + baseClass + '-label">' + label + '</span><span class="' + baseClass + '-value">' + value + '</span></div>';
  }

  /**
   * shows the bottom sheet with detailed fountain information.
   */
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

  /**
   * hides the bottom sheet panel.
   */
  function hideBottomSheet() {
    if (!dom.bottomSheet || !dom.overlay) {
      return;
    }

    dom.bottomSheet.classList.remove('active');
    dom.overlay.classList.remove('active');
    state.currentFountain = null;
  }

  /**
   * prepares html blocks for additional instagram posts.
   */
  function generateInstagramPosts(posts) {
    if (!posts || posts.length === 0) {
      return '';
    }

    const cards = posts.slice(0, 3).map((post) => {
      const caption = post.caption ? `<div class="instagram-post-caption">${post.caption}</div>` : '';
      return [
        '<div class="instagram-post">',
        '<div class="instagram-post-header">',
        `<span class="instagram-post-rating">⭐ ${post.rating}/10</span>`,
        `<span class="instagram-post-date">${formatDate(post.date_posted)}</span>`,
        '</div>',
        caption,
        `<a href="${post.url}" target="_blank" class="instagram-post-link">`,
        '<i class="fab fa-instagram"></i> View on Instagram',
        '</a>',
        '</div>'
      ].join('');
    });

    if (posts.length > 3) {
      cards.push(`<div style="text-align: center; margin-top: 10px;"><small>+${posts.length - 3} more posts...</small></div>`);
    }

    return cards.join('');
  }

  /**
   * returns true for mobile viewport widths.
   */
  function isMobile() {
    return window.innerWidth <= 768;
  }

  /**
   * checks for touch capable devices.
   */
  function isTouchDevice() {
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0 || navigator.msMaxTouchPoints > 0;
  }

  /**
   * throttle helper to limit how often a function runs.
   */
  function throttle(fn, wait) {
    let timeoutId;
    return (...args) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        fn(...args);
      }, wait);
    };
  }

  /**
   * picks the latest instagram post from the fountain payload.
   */
  function pickLatestInstagramPost(fountain) {
    if (!fountain.instagram_posts || fountain.instagram_posts.length === 0) {
      return null;
    }
    return fountain.instagram_posts[0];
  }

  /**
   * normalizes pet friendly values for display.
   */
  function formatPetFriendly(value) {
    if (value === true) {
      return 'Yes';
    }
    if (value === false) {
      return 'No';
    }
    if (!value) {
      return 'unknown';
    }
    if (typeof value === 'string') {
      const lower = value.toLowerCase();
      if (lower.includes('yes') || lower.includes('y')) {
        return 'Yes';
      }
      if (lower.includes('no') || lower.includes('n')) {
        return 'No';
      }
      if (lower === 'na' || lower === 'unknown') {
        return 'unknown';
      }
    }
    return 'unknown';
  }

  /**
   * normalizes operational values for display.
   */
  function formatOperational(value) {
    if (value === true) {
      return 'Yes';
    }
    if (value === false) {
      return 'No';
    }
    if (!value) {
      return 'unknown';
    }
    if (typeof value === 'string' && (value.toLowerCase() === 'na' || value.toLowerCase() === 'unknown')) {
      return 'unknown';
    }
    return value;
  }

  /**
   * derives instagram media urls from post links.
   */
  function getInstagramPhotoUrl(instagramUrl) {
    if (!instagramUrl) {
      return null;
    }
    const match = instagramUrl.match(/\/p\/([^\/]+)\//);
    if (match) {
      const postId = match[1];
      return `https://instagram.com/p/${postId}/media/?size=m`;
    }
    return null;
  }

  /**
   * detects whether the latest review came from the admin account.
   */
  function isAdminReview(fountain) {
    const reviewer = fountain.latest_reviewer;
    if (!reviewer) {
      return false;
    }
    const normalized = reviewer.toLowerCase();
    return normalized === 'yvr water fountains' || normalized === 'yvrwaterfountains';
  }

  /**
   * formats iso date strings into a friendly format.
   */
  function formatDate(dateString) {
    if (!dateString) {
      return '';
    }
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
  }

  /**
   * placeholder action for linking to a detailed fountain page.
   */
  function showFountainDetails(fountainId) {
    console.log('show fountain details for:', fountainId);
  }

  /**
   * placeholder action for opening the full reviews view.
   */
  function showAllReviews(fountainId) {
    console.log('show all reviews for fountain:', fountainId);
  }
})();
