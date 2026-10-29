'use strict';

(function () {
  const config = window.APP_CONFIG || {};

  // Settings
  const CONTACT_EMAIL = 'yvrwaterfountains@gmail.com';   // Report an issue and suggest a correction go here until the reports PR
  const RATING_NUMBERS_FROM_ZOOM = 15;                    // pins show the latest rating from this zoom in

  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // Words beside a mark in the fountain info
  const KIND_LABELS = {
    ours: 'By us',
    both: 'Us + public',
    public: 'Public',
    none: 'Not reviewed',
    issue: 'Issue reported'
  };

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
      addLegend();
      registerRatingNumbers();
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
   * which mark a fountain gets (the marks note on the design canvas):
   * issue = open issue, ours = only our reviews, both = ours and public,
   * public = only public reviews, none = not reviewed yet.
   */
  function markKind(fountain) {
    if (fountain.issue_reported_at) {
      return 'issue';
    }
    const ours = (fountain.admin_review_count || 0) > 0;
    const publicReviews = (fountain.public_review_count || 0) > 0;
    if (ours && publicReviews) {
      return 'both';
    }
    if (ours) {
      return 'ours';
    }
    if (publicReviews || (fountain.rating_count || 0) > 0) {
      return 'public';
    }
    return 'none';
  }

  /**
   * draws one mark per fountain; rated fountains carry their latest rating.
   */
  function placeFountainsOnMap(geojson) {
    L.geoJSON(geojson, {
      pointToLayer: (feature, latlng) => {
        const props = feature.properties || {};
        const kind = markKind(props);
        const rated = props.rating !== null && props.rating !== undefined;
        const size = rated || kind === 'issue' ? 22 : 12;

        const icon = L.divIcon({
          className: 'fountain-pin',
          html: buildMark(kind, rated ? formatRating(props.rating) : ''),
          iconSize: [size, size],
          iconAnchor: [size / 2, size / 2]
        });

        return L.marker(latlng, {
          icon,
          title: props.name || 'Fountain',
          zIndexOffset: kind === 'none' ? 0 : 500
        });
      },
      onEachFeature: (feature, layer) => attachFountainBehavior(feature, layer)
    }).addTo(state.map);
  }

  /**
   * opens the fountain info: a bottom sheet on phones, a popup on wider screens.
   */
  function attachFountainBehavior(feature, layer) {
    const properties = feature.properties || {};

    if (isMobile()) {
      layer.on('click', () => showBottomSheet(properties));
    } else {
      // build the info once per opening; popup.update() then only resizes it
      layer.bindPopup('', { maxWidth: 340, minWidth: 280 });
      layer.on('popupopen', (event) => {
        const popup = event.popup;
        popup.setContent(buildFountainInfo(properties, () => popup.update()));
      });
    }

    if (properties.id) {
      state.markerById.set(properties.id, layer);
    }
  }

  /**
   * legend with the same marks as the pins.
   */
  function addLegend() {
    const legend = L.control({ position: 'topright' });
    legend.onAdd = () => {
      const box = el('div', 'map-legend');
      const rows = [
        ['ours', 'Reviewed by us'],
        ['public', 'Public reviews only'],
        ['both', 'Both'],
        ['none', 'Not reviewed yet'],
        ['issue', 'Issue reported']
      ];
      rows.forEach(([kind, label]) => {
        const row = el('div', 'map-legend-row');
        row.append(buildMark(kind, ''), document.createTextNode(label));
        box.append(row);
      });
      box.append(el('div', 'map-legend-note', 'Number = latest rating'));
      L.DomEvent.disableClickPropagation(box);
      return box;
    };
    legend.addTo(state.map);
  }

  /**
   * hides the rating numbers on pins below RATING_NUMBERS_FROM_ZOOM.
   */
  function registerRatingNumbers() {
    const update = () => {
      state.map.getContainer().classList.toggle('show-ratings', state.map.getZoom() >= RATING_NUMBERS_FROM_ZOOM);
    };
    state.map.on('zoomend', update);
    update();
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
        showBottomSheet(fountain.properties || {});
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
   * builds the fountain info shown in both the phone sheet and the desktop popup.
   * every database string goes in with textContent (via el) or through safeUrl.
   * onVisitsLoaded runs after the all-visits list arrives (the popup resizes).
   */
  function buildFountainInfo(fountain, onVisitsLoaded) {
    const kind = markKind(fountain);
    const info = el('div', 'fountain-info ' + kind);

    // Name, where it is, and who reviewed it
    const head = el('div', 'info-head');
    const titles = el('div', 'info-titles');
    titles.append(el('div', 'info-title', fountain.name || 'Unnamed fountain'));
    const location = sameText(fountain.location, fountain.name) ? null : fountain.location;
    const where = [fountain.neighborhood, location].filter(Boolean).join(' \u00B7 ');
    if (where) {
      titles.append(el('div', 'info-subtitle', where));
    }
    const badge = el('div', 'info-badge');
    badge.append(buildMark(kind, ''), document.createTextNode(KIND_LABELS[kind]));
    head.append(titles, badge);
    info.append(head);

    // Latest rating, average, photo and post link
    if (fountain.rating !== null && fountain.rating !== undefined) {
      const ratingRow = el('div', 'info-rating-row');
      const latest = el('div', 'info-latest');
      latest.append(el('div', 'info-latest-number', formatRating(fountain.rating)));
      if (fountain.latest_visit_date) {
        latest.append(el('div', 'info-latest-date', 'last visited ' + formatDate(fountain.latest_visit_date)));
      }
      const side = el('div', 'info-rating-side');
      const visits = fountain.rating_count || 0;
      if (fountain.avg_rating !== null && fountain.avg_rating !== undefined) {
        const average = el('div', 'info-average', 'Average ');
        average.append(el('strong', '', formatAverage(fountain.avg_rating)),
          document.createTextNode(' from ' + visits + (visits === 1 ? ' visit' : ' visits')));
        side.append(average);
      }
      const post = buildPostLink(fountain);
      if (post) {
        side.append(post);
      }
      ratingRow.append(latest, side);
      info.append(ratingRow);
    } else {
      info.append(el('div', 'info-unrated', 'Not reviewed yet'));
    }

    // Open issue (maintenance only; seasonal and closed are details)
    if (fountain.issue_reported_at) {
      const issue = 'Issue reported ' + formatDate(fountain.issue_reported_at) + (fountain.issue_note ? ': ' + fountain.issue_note : '');
      info.append(el('div', 'info-issue', issue));
    }

    info.append(buildDetails(fountain));

    // Every approved review, newest visit first
    const visitList = el('div', 'info-visits');
    visitList.append(el('div', 'info-visits-note', fountain.rating_count ? 'Loading visits\u2026' : 'No reviews yet. Be the first.'));
    info.append(visitList);
    if (fountain.rating_count) {
      loadVisits(fountain, visitList).then(() => {
        if (onVisitsLoaded) {
          onVisitsLoaded();
        }
      });
    }

    info.append(buildActions(fountain));
    return info;
  }

  /**
   * photo from the latest post (when the link allows one) and the post link.
   */
  function buildPostLink(fountain) {
    const link = safeUrl(fountain.latest_review_author_type === 'admin' ? latestPostUrl(fountain) : null);
    if (!link) {
      return null;
    }
    const row = el('div', 'info-post');
    const photoUrl = storedPhotoUrl(fountain);
    if (photoUrl) {
      const photo = document.createElement('img');
      photo.className = 'info-photo';
      photo.src = photoUrl;
      photo.alt = 'Photo from the @yvrwaterfountains post';
      photo.addEventListener('error', () => photo.remove());
      row.append(photo);
    }
    const anchor = el('a', 'info-post-link', '@yvrwaterfountains post');
    anchor.href = link;
    anchor.target = '_blank';
    anchor.rel = 'noopener';
    row.append(anchor);
    return row;
  }

  /**
   * details, each Yes / No / Unknown, plus Closed or the season note when set.
   */
  function buildDetails(fountain) {
    const details = el('div', 'info-details');
    const addDetail = (label, value, wide) => {
      const item = el('div', wide ? 'info-detail wide' : 'info-detail');
      item.append(el('span', 'info-detail-label', label + ' '), el('strong', '', value));
      details.append(item);
    };

    addDetail('Anti-freeze', yesNoUnknown(fountain.anti_freeze));
    addDetail('Bottle filler', yesNoUnknown(fountain.bottle_filler));
    addDetail('Accessible', yesNoUnknown(fountain.wheelchair_accessible));
    addDetail('Pet friendly', yesNoUnknown(fountain.pet_friendly));
    if (fountain.indoor === 'Yes') {
      addDetail('Indoor', 'Yes, may be locked outside opening hours', true);
    } else {
      addDetail('Indoor', yesNoUnknown(fountain.indoor));
    }

    if (fountain.operational_status === 'closed') {
      addDetail('Status', fountain.season_note ? 'Closed (' + fountain.season_note + ')' : 'Closed', true);
    } else if (fountain.operational_status === 'seasonal') {
      addDetail('Season', fountain.season_note || 'Seasonal', true);
    }
    return details;
  }

  /**
   * reads the approved reviews and fills the visits list.
   */
  async function loadVisits(fountain, container) {
    try {
      const reviews = await FountainData.fetchReviews(fountain.supabase_id);
      container.replaceChildren(el('div', 'info-visits-title', reviews.length === 1 ? '1 visit' : reviews.length + ' visits'));
      reviews.forEach((review) => {
        const item = el('div', 'info-visit');
        const meta = el('div', 'info-visit-meta', formatDate(review.visit_date) + ' \u00B7 ' + reviewerName(review) + ' \u00B7 ');
        meta.append(el('strong', '', formatRating(review.rating)));
        item.append(meta);
        if (review.review_text) {
          item.append(el('div', 'info-visit-text', review.review_text));
        }
        container.append(item);
      });
    } catch (error) {
      console.warn('could not load reviews', error);
      container.replaceChildren(el('div', 'info-visits-note', 'Could not load the visits right now.'));
    }
  }

  function reviewerName(review) {
    if (review.author_type === 'admin') {
      return '@yvrwaterfountains';
    }
    return review.reviewer_name || 'Anonymous';
  }

  /**
   * Review this fountain, Report an issue, and suggest a correction.
   */
  function buildActions(fountain) {
    const actions = el('div', 'info-actions');
    const review = el('a', 'info-btn primary', 'Review this fountain');
    review.href = fountain.supabase_id ? 'review.html?fountain=' + encodeURIComponent(fountain.supabase_id) : 'review.html';
    const report = el('a', 'info-btn secondary', 'Report an issue');
    report.href = mailtoLink('Issue at', fountain);
    actions.append(review, report);

    const correction = el('div', 'info-correction');
    const correctionLink = el('a', '', 'suggest a correction');
    correctionLink.href = mailtoLink('Correction for', fountain);
    correction.append(el('span', '', 'Off for winter, wrong spot, wrong details?'), correctionLink);

    const wrap = el('div', 'info-actions-wrap');
    wrap.append(actions, correction);
    return wrap;
  }

  function mailtoLink(subjectStart, fountain) {
    const name = fountain.name || 'a fountain';
    const body = 'Fountain: ' + name + '\nID: ' + (fountain.id || '') + '\n\nWhat we should know:\n';
    return 'mailto:' + CONTACT_EMAIL + '?subject=' + encodeURIComponent(subjectStart + ' ' + name) + '&body=' + encodeURIComponent(body);
  }

  /**
   * shows the bottom sheet with the fountain info.
   */
  function showBottomSheet(fountain) {
    if (!dom.bottomSheet || !dom.bottomSheetContent || !dom.overlay) {
      return;
    }

    state.currentFountain = fountain;

    // Colour bar follows the mark
    const colorBar = document.getElementById('sheet-color-bar');
    if (colorBar) {
      colorBar.className = 'sheet-color-bar ' + markKind(fountain);
    }

    dom.bottomSheetContent.replaceChildren(buildFountainInfo(fountain));
    dom.bottomSheet.scrollTop = 0;
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
   * the post link of the latest review, if it has one.
   */
  function latestPostUrl(fountain) {
    const posts = fountain.instagram_posts || [];
    return posts.length > 0 ? posts[0].url : null;
  }

  /**
   * the post's photo, only when a copy is kept in the project's Supabase Storage
   * (Instagram's own image links expire within days).
   */
  function storedPhotoUrl(fountain) {
    const posts = fountain.instagram_posts || [];
    const url = posts.length > 0 ? posts[0].photo_url : null;
    const storage = (config.SUPABASE_URL || '') + '/storage/v1/object/public/';
    return typeof url === 'string' && config.SUPABASE_URL && url.startsWith(storage) ? url : null;
  }

  /**
   * a mark: one span styled by theme.css, with an optional rating inside.
   */
  function buildMark(kind, text) {
    const mark = el('span', 'mark mark-' + kind, text);
    mark.setAttribute('aria-hidden', 'true');
    return mark;
  }

  /**
   * creates an element with a class and optional text (text is never parsed as html).
   */
  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) {
      node.className = className;
    }
    if (text !== undefined && text !== null) {
      node.textContent = String(text);
    }
    return node;
  }

  // 8 -> '8', 7.5 -> '7½'
  function formatRating(value) {
    const number = Number(value);
    if (!Number.isFinite(number)) {
      return '';
    }
    const whole = Math.floor(number);
    return number - whole >= 0.5 ? whole + '\u00BD' : String(whole);
  }

  // 7.25 -> '7.3', 8.0 -> '8'
  function formatAverage(value) {
    const rounded = Number(value).toFixed(1);
    return rounded.endsWith('.0') ? rounded.slice(0, -2) : rounded;
  }

  // '2026-10-14' -> '14 Oct 2026', read straight from the date (no time zone shifts)
  function formatDate(isoDate) {
    if (!isoDate) {
      return 'no date';
    }
    const [year, month, day] = String(isoDate).slice(0, 10).split('-').map(Number);
    return day + ' ' + MONTHS[month - 1] + ' ' + year;
  }

  function sameText(a, b) {
    return Boolean(a && b) && String(a).trim().toLowerCase() === String(b).trim().toLowerCase();
  }

  function yesNoUnknown(value) {
    return value === 'Yes' || value === 'No' ? value : 'Unknown';
  }

  /**
   * returns the url only if it is an https link to instagram.com.
   */
  function safeUrl(url) {
    return typeof url === 'string' && /^https:\/\/(www\.)?instagram\.com\//i.test(url) ? url : null;
  }
})();
