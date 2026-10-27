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
    locateButton: null
  };

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
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(state.map);
  }

  /**
   * sets a viewport appropriate for the device size.
   */
  function applyInitialView() {
    if (isMobile()) {
      state.map.setView([config.MAP_CENTER[0] + 0.01, config.MAP_CENTER[1]], config.MAP_ZOOM);
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
      radius: isMobile() ? 6 : 5,
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
    L.geoJSON(geojson, {
      pointToLayer: (feature, latlng) => {
        const props = feature.properties || {};
        const style = markerStyle(props);
        return L.circleMarker(latlng, style);
      },
      onEachFeature: (feature, layer) => attachFountainBehavior(feature, layer)
    }).addTo(state.map);
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
   * renders the popup markup for desktop visitors.
   * every database string goes through escapeHtml or safeUrl.
   */
  function buildPopupContent(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
    const isReviewed = (fountain.admin_review_count || 0) > 0;
    const isCommunity = !isReviewed && (fountain.rating_count || 0) > 0;
    const typeClass = isReviewed ? ' reviewed' : isCommunity ? ' community-reviewed' : '';

    let html = '<div class="popup-content' + typeClass + '">';

    // Title with optional photo
    if (latestPhotoUrl) {
      html += '<img src="' + escapeHtml(latestPhotoUrl) + '" alt="Photo" style="width:80px;height:80px;border-radius:10px;float:right;margin-left:10px;object-fit:cover;" onerror="this.style.display=\'none\'">';
    }
    html += '<div class="popup-title">' + escapeHtml(fountain.name || 'Unnamed Fountain') + '</div>';

    // Info section
    html += '<div class="info-section">';
    html += buildInfoRow('popup', 'Location', escapeHtml(fountain.location || fountain.address || '\u2014'));
    html += buildInfoRow('popup', 'Neighbourhood', escapeHtml(fountain.neighborhood || '\u2014'));

    if (fountain.avg_rating) {
      const count = fountain.rating_count || 0;
      const avg = Number.parseFloat(fountain.avg_rating).toFixed(1);
      html += buildInfoRow('popup', 'Rating', '<span class="rating-badge">' + avg + '/10</span> (' + count + ' review' + (count !== 1 ? 's' : '') + ')');
    }

    html += buildInfoRow('popup', 'Operational', escapeHtml(formatOperational(fountain.currently_operational)));
    if (fountain.is_indoor) {
      html += buildInfoRow('popup', 'Indoor', 'Yes, may be locked outside opening hours');
    }
    html += buildInfoRow('popup', 'Pet Friendly', escapeHtml(formatPetFriendly(fountain.pet_friendly)));
    html += '</div>';

    // Caption
    if (fountain.caption) {
      const truncated = fountain.caption.length > 200 ? fountain.caption.slice(0, 200) + '...' : fountain.caption;
      html += '<div class="caption-box">' + escapeHtml(truncated) + '</div>';
    }

    // Instagram link
    if (latestInstagramPost && safeUrl(latestInstagramPost.url)) {
      html += '<a href="' + escapeHtml(safeUrl(latestInstagramPost.url)) + '" target="_blank" rel="noopener" class="ig-link">@yvrwaterfountains post \u2192</a>';
    }

    // Public reviews are paused until the new review form ships
    if (!fountain.rating) {
      html += '<a href="https://www.instagram.com/yvrwaterfountains/" target="_blank" class="cta-btn">Not reviewed yet. Public reviews open soon!</a>';
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
      html += '<img src="' + escapeHtml(latestPhotoUrl) + '" alt="Photo" class="sheet-photo" onerror="this.style.display=\'none\'">';
      html += '<div class="sheet-header-text">';
    } else {
      html += '<div style="margin-bottom:1rem;">';
    }

    html += '<div class="bottom-sheet-title">' + escapeHtml(fountain.name || 'Unnamed Fountain') + '</div>';
    html += '<div class="sheet-subtitle">' + escapeHtml((fountain.neighborhood || '') + (fountain.location ? ' \u00B7 ' + fountain.location : '')) + '</div>';

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
    html += buildInfoRow('bottom-sheet', 'Operational', escapeHtml(formatOperational(fountain.currently_operational)));
    if (fountain.is_indoor) {
      html += buildInfoRow('bottom-sheet', 'Indoor', 'Yes, may be locked outside opening hours');
    }
    html += buildInfoRow('bottom-sheet', 'Pet Friendly', escapeHtml(formatPetFriendly(fountain.pet_friendly)));

    if (fountain.rating) {
      const reviewer = adminReview ? '@yvrwaterfountains' : (fountain.latest_reviewer || 'Anonymous');
      html += buildInfoRow('bottom-sheet', 'Reviewed by', escapeHtml(reviewer));
    }

    if (fountain.wheelchair_accessible && fountain.wheelchair_accessible !== 'unknown') {
      html += buildInfoRow('bottom-sheet', 'Wheelchair', escapeHtml(fountain.wheelchair_accessible));
    }
    html += '</div>';

    // Caption
    if (fountain.caption) {
      html += '<div class="sheet-caption">' + escapeHtml(fountain.caption) + '</div>';
    }

    // Action buttons
    html += '<div class="sheet-actions">';
    if (latestInstagramPost && safeUrl(latestInstagramPost.url)) {
      html += '<a href="' + escapeHtml(safeUrl(latestInstagramPost.url)) + '" target="_blank" rel="noopener" class="sheet-action-btn primary">View on Instagram</a>';
    }
    // Public reviews are paused until the new review form ships
    html += '<a href="https://www.instagram.com/yvrwaterfountains/" target="_blank" class="sheet-action-btn secondary">Public reviews open soon</a>';
    html += '</div>';

    return html;
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
   * a review is ours when the database says it was written by an admin.
   */
  function isAdminReview(fountain) {
    return fountain.latest_review_author_type === 'admin';
  }

  /**
   * escapes text before it goes into html.
   */
  function escapeHtml(value) {
    return String(value === null || value === undefined ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  /**
   * returns the url only if it is a plain http(s) link.
   */
  function safeUrl(url) {
    return typeof url === 'string' && /^https?:\/\//i.test(url) ? url : null;
  }
})();
