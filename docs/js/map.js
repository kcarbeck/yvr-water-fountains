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
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
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

    dom.adminButton.addEventListener('click', (event) => {
      event.preventDefault();
      if (!window.hasSupabaseCredentials || !window.hasSupabaseCredentials()) {
        alert('configure supabase url and anon key in config.js to open the admin tools.');
        return;
      }

      showAdminPanel();
    });
  }

  /**
   * draws markers using the geojson payload.
   */
  function placeFountainsOnMap(geojson) {
    L.geoJSON(geojson, {
      pointToLayer: (feature, latlng) => L.circleMarker(latlng, {
        radius: 8,
        color: '#007bff',
        fillColor: '#007bff',
        fillOpacity: 0.7,
        weight: 2
      }),
      onEachFeature: (feature, layer) => attachFountainBehavior(feature, layer)
    }).addTo(state.map);
  }

  /**
   * adds click and popup behavior for each fountain marker.
   */
  function attachFountainBehavior(feature, layer) {
    const properties = feature.properties || {};
    const latestInstagramPost = pickLatestInstagramPost(properties);
    const latestPhotoUrl = latestInstagramPost ? getInstagramPhotoUrl(latestInstagramPost) : null;
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
        const latestPhotoUrl = latestInstagramPost ? getInstagramPhotoUrl(latestInstagramPost) : null;
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
      '<p style="margin: 10px 0; font-size: 0.9rem;">sign in with your supabase admin email to continue.</p>',
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
   * renders the popup markup for desktop visitors.
   */
  function buildPopupContent(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
    let html = '<div class="popup-content">';
    html += '<div class="popup-title">';
    html += `<a href="#" class="popup-title-link" onclick="showFountainDetails('${fountain.id || ''}')">${fountain.name || 'Unnamed Fountain'}</a>`;
    html += '</div>';
    html += buildInfoRow('popup', '📍 Location:', fountain.location || fountain.address || '—');
    html += buildInfoRow('popup', '🏘️ Neighbourhood:', fountain.neighborhood || '—');
    html += buildInfoRow('popup', '🏢 Operational:', formatOperational(fountain.currently_operational));
    html += buildInfoRow('popup', '🐕 Pet Friendly:', formatPetFriendly(fountain.pet_friendly));

    if (fountain.avg_rating) {
      const reviewsLabel = `${fountain.rating_count} review${fountain.rating_count !== 1 ? 's' : ''}`;
      const average = `${Number.parseFloat(fountain.avg_rating).toFixed(1)}/10`;
      const ratingLink = `<a href="#" class="popup-clickable" onclick="showAllReviews('${fountain.id || ''}')">${average}</a> (${reviewsLabel})`;
      html += buildInfoRow('popup', '⭐ Avg Rating:', ratingLink);
    }

    if (fountain.rating) {
      const reviewer = fountain.latest_reviewer || 'Anonymous';
      const ratingDisplay = adminReview && latestInstagramPost
        ? `<a href="${latestInstagramPost.url}" target="_blank" class="popup-clickable">${fountain.rating}/10 by ${reviewer}</a>`
        : `${fountain.rating}/10 by ${reviewer}`;
      html += buildInfoRow('popup', '📝 Latest Review:', ratingDisplay);
    }

    if (fountain.wheelchair_accessible) {
      html += buildInfoRow('popup', '♿ Wheelchair:', fountain.wheelchair_accessible);
    }

    if (fountain.bottle_filler) {
      html += buildInfoRow('popup', '💧 Bottle Filler:', fountain.bottle_filler);
    }

    if (latestInstagramPost) {
      const instagramBlock = buildInstagramPreview(latestInstagramPost, latestPhotoUrl);
      html += buildInfoRow('popup', '📸 Latest Instagram:', instagramBlock);
    }

    if (fountain.caption && !adminReview) {
      html += buildInfoRow('popup', '📝 Notes:', fountain.caption);
    }

    html += '</div>';
    return html;
  }

  /**
   * renders the bottom sheet markup for mobile visitors.
   */
  function buildBottomSheetContent(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
    let html = '<div class="bottom-sheet-title">';
    html += `<a href="#" class="popup-title-link" onclick="showFountainDetails('${fountain.id || ''}')">${fountain.name || 'Unnamed Fountain'}</a>`;
    html += '</div>';
    html += buildInfoRow('bottom-sheet', '📍 Location:', fountain.location || fountain.address || '—');
    html += buildInfoRow('bottom-sheet', '🏘️ Neighbourhood:', fountain.neighborhood || '—');
    html += buildInfoRow('bottom-sheet', '🏢 Operational:', formatOperational(fountain.currently_operational));
    html += buildInfoRow('bottom-sheet', '🐕 Pet Friendly:', formatPetFriendly(fountain.pet_friendly));

    if (fountain.avg_rating) {
      const reviewsLabel = `${fountain.rating_count} review${fountain.rating_count !== 1 ? 's' : ''}`;
      const average = `${Number.parseFloat(fountain.avg_rating).toFixed(1)}/10`;
      const ratingLink = `<a href="#" class="popup-clickable" onclick="showAllReviews('${fountain.id || ''}')">${average}</a> (${reviewsLabel})`;
      html += buildInfoRow('bottom-sheet', '⭐ Avg Rating:', ratingLink);
    }

    if (fountain.rating) {
      const reviewer = fountain.latest_reviewer || 'Anonymous';
      const ratingDisplay = adminReview && latestInstagramPost
        ? `<a href="${latestInstagramPost.url}" target="_blank" class="popup-clickable">${fountain.rating}/10 by ${reviewer}</a>`
        : `${fountain.rating}/10 by ${reviewer}`;
      html += buildInfoRow('bottom-sheet', '📝 Latest Review:', ratingDisplay);
    }

    if (fountain.wheelchair_accessible) {
      html += buildInfoRow('bottom-sheet', '♿ Wheelchair:', fountain.wheelchair_accessible);
    }

    if (fountain.bottle_filler) {
      html += buildInfoRow('bottom-sheet', '💧 Bottle Filler:', fountain.bottle_filler);
    }

    if (latestInstagramPost) {
      const instagramBlock = buildInstagramPreview(latestInstagramPost, latestPhotoUrl);
      html += buildInfoRow('bottom-sheet', '📸 Latest Instagram:', instagramBlock);
    }

    if (fountain.caption && !adminReview) {
      html += buildInfoRow('bottom-sheet', '📝 Notes:', fountain.caption);
    }

    if (fountain.has_instagram && fountain.instagram_posts && fountain.instagram_posts.length > 1) {
      const remainingPosts = fountain.instagram_posts.slice(1);
      const postsHtml = generateInstagramPosts(remainingPosts);
      if (postsHtml) {
        html += buildInfoRow('bottom-sheet', '📸 All Instagram Posts:', `<div class="instagram-posts-container" id="instagram-${fountain.id}">${postsHtml}</div>`);
      }
    }

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
    return [
      `<div class="${baseClass}-info">`,
      `<span class="${baseClass}-label">${label}</span>`,
      `<span class="${baseClass}-value">${value}</span>`,
      '</div>'
    ].join('');
  }

  /**
   * shows the bottom sheet with detailed fountain information.
   */
  function showBottomSheet(fountain, latestInstagramPost, latestPhotoUrl, adminReview) {
    if (!dom.bottomSheet || !dom.bottomSheetContent || !dom.overlay) {
      return;
    }

    state.currentFountain = fountain;
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
  function getInstagramPhotoUrl(post) {
    if (!post) {
      return null;
    }
    if (post.photo_url) {
      return post.photo_url;
    }
    const instagramUrl = post.url;
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
    if (fountain.latest_review_author_type) {
      return fountain.latest_review_author_type === 'admin';
    }
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
