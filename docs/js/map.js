'use strict';

(function () {
  const config = window.APP_CONFIG || {};

  // Settings
  const CONTACT_EMAIL = 'yvrwaterfountains@gmail.com';   // "Report an issue" and "suggest a correction" open an email to this address
  // Pins stay a fixed size on screen, like most web maps, in four small steps
  // (sizes in map.html): 8 px dots, 11 px, 14 px with the rating, 16 px
  const FAR_ZOOM = 11;                                    // at this zoom and out: smallest dots
  const RATING_NUMBERS_FROM_ZOOM = 13;                    // pins show the latest rating from this zoom in
  const CLOSE_ZOOM = 15;                                  // from this zoom in: pins one step bigger
  const STACK_METRES = 20;                                // fountains this close are fanned out until zoomed in enough to separate
  const POPUP_MAX_HEIGHT = 440;                           // desktop popup scrolls beyond this many pixels
  const LONG_REVIEW_CHARACTERS = 240;                     // longer reviews are cut short with "Read more"

  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // The five marks: words in the legend, and the short badge in the fountain info
  const KINDS = {
    ours: { legend: 'Reviewed by us', badge: 'By us' },
    public: { legend: 'Public reviews only', badge: 'Public' },
    both: { legend: 'Both', badge: 'Us + public' },
    none: { legend: 'Not reviewed yet', badge: 'Not reviewed yet' },
    issue: { legend: 'Issue reported or closed', badge: 'Issue reported' }
  };

  const state = {
    map: null,
    markerById: new Map(),
    stacks: [],
    fountains: [],
    currentFountain: null,
    pageScrollY: 0
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
      state.stacks = findStacks([...state.markerById.values()]);
      registerZoomStyles();
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

    // Swipe down to close, but only when the swipe starts with the sheet
    // scrolled to its top (otherwise the swipe is scrolling the reviews back up).
    // The listeners are passive: they never block the sheet's own scrolling.
    let swipeStartY = 0;
    let startedAtTop = false;
    dom.bottomSheet.addEventListener('touchstart', (event) => {
      swipeStartY = event.touches[0].clientY;
      startedAtTop = dom.bottomSheet.scrollTop <= 0;
    }, { passive: true });

    dom.bottomSheet.addEventListener('touchend', (event) => {
      const movedDown = event.changedTouches[0].clientY - swipeStartY;
      if (startedAtTop && movedDown > 100) {
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
   * which mark a fountain gets: issue = an open issue or closed for good
   * (whoever reviewed it),
   * ours = only our reviews, both = ours and public, public = only public
   * reviews, none = no approved review yet.
   */
  function markKind(fountain) {
    if (fountain.issue_reported_at || fountain.operational_status === 'closed') {
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
        const rating = formatRating(props.rating);

        // a 26 px tap area for every pin, larger than the dot you see inside it
        const icon = L.divIcon({
          className: 'fountain-pin',
          html: buildMark(kind, rating),
          iconSize: [26, 26],
          iconAnchor: [13, 13]
        });

        // the title is what screen readers announce for a pin
        const title = (props.name || 'Fountain') + ', ' + KINDS[kind].legend.toLowerCase() +
          (rating ? ', latest rating ' + rating + ' out of 10' : '');

        return L.marker(latlng, {
          icon,
          title,
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
      // the info is built once each time the popup opens; popup.update()
      // re-measures it after the visits arrive
      layer.bindPopup('', { maxWidth: 340, minWidth: 280, maxHeight: POPUP_MAX_HEIGHT });
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
      Object.keys(KINDS).forEach((kind) => {
        const row = el('div', 'map-legend-row');
        row.append(buildMark(kind, ''), document.createTextNode(KINDS[kind].legend));
        box.append(row);
      });
      box.append(el('div', 'map-legend-note', 'Zoom in to see each latest rating'));
      L.DomEvent.disableClickPropagation(box);
      return box;
    };
    legend.addTo(state.map);
  }

  /**
   * after each zoom: tells the stylesheet which zoom band the map is in (pin
   * sizes), then fans out stacked fountains to suit the new pin size.
   */
  function registerZoomStyles() {
    const update = () => {
      const zoom = state.map.getZoom();
      const container = state.map.getContainer();
      container.classList.toggle('pins-far', zoom <= FAR_ZOOM);
      container.classList.toggle('show-ratings', zoom >= RATING_NUMBERS_FROM_ZOOM);
      container.classList.toggle('pins-close', zoom >= CLOSE_ZOOM);
      spreadStacks();
    };
    state.map.on('zoomend', update);
    update();
  }

  /**
   * groups markers that sit within STACK_METRES of each other (27 fountains
   * share exact coordinates in the city data, up to 6 at one spot).
   * Each marker keeps its true position (home); each stack its centre.
   */
  function findStacks(markers) {
    const stacks = [];
    markers.forEach((marker) => {
      marker.home = marker.getLatLng();
      const stack = stacks.find((s) => s.markers.some((m) => m.home.distanceTo(marker.home) < STACK_METRES));
      if (stack) {
        stack.markers.push(marker);
      } else {
        stacks.push({ markers: [marker] });
      }
    });

    const stacked = stacks.filter((s) => s.markers.length > 1);
    stacked.forEach((s) => {
      const lat = s.markers.reduce((sum, m) => sum + m.home.lat, 0) / s.markers.length;
      const lng = s.markers.reduce((sum, m) => sum + m.home.lng, 0) / s.markers.length;
      s.centre = L.latLng(lat, lng);
    });
    return stacked;
  }

  /**
   * while a stack's pins would overlap on screen, places them on a small ring
   * around its centre, a little more than one pin apart, so each can be seen
   * and tapped. Once zoomed in far enough for them to sit apart, each pin goes
   * back to its true position (pins with identical coordinates never do).
   */
  function spreadStacks() {
    const pin = document.querySelector('.fountain-pin .mark');
    const pinSize = pin ? pin.offsetWidth : 12;
    const zoom = state.map.getZoom();

    state.stacks.forEach((stack) => {
      if (pinsSitApart(stack.markers, pinSize, zoom)) {
        stack.markers.forEach((marker) => marker.setLatLng(marker.home));
        return;
      }
      const count = stack.markers.length;
      // ring radius so that neighbouring pins are about 1.15 pins apart
      const radius = Math.max(pinSize * 0.6, (pinSize * 0.575) / Math.sin(Math.PI / count));
      const centre = state.map.project(stack.centre, zoom);
      stack.markers.forEach((marker, i) => {
        const angle = -Math.PI / 2 + (2 * Math.PI * i) / count;
        const point = centre.add([radius * Math.cos(angle), radius * Math.sin(angle)]);
        marker.setLatLng(state.map.unproject(point, zoom));
      });
    });
  }

  // true when, at this zoom, every pair of the stack's true positions is at
  // least two pins apart on screen
  function pinsSitApart(markers, pinSize, zoom) {
    const points = markers.map((m) => state.map.project(m.home, zoom));
    return points.every((a, i) => points.every((b, j) => i === j || a.distanceTo(b) >= pinSize * 2));
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
    const info = el('div', 'fountain-info kind-' + kind);

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
    const closedOnly = fountain.operational_status === 'closed' && !fountain.issue_reported_at;
    badge.append(buildMark(kind, ''), document.createTextNode(closedOnly ? 'Closed' : KINDS[kind].badge));
    head.append(titles, badge);
    info.append(head);

    // Latest rating, average, photo and post link
    if (formatRating(fountain.rating)) {
      const ratingRow = el('div', 'info-rating-row');
      const latest = el('div', 'info-latest');
      const number = el('div', 'info-latest-number', formatRating(fountain.rating));
      number.append(el('span', 'info-out-of', '/10'));
      latest.append(number);
      if (fountain.latest_visit_date) {
        latest.append(el('div', 'info-latest-date', 'last visited ' + formatDate(fountain.latest_visit_date)));
      }
      const side = el('div', 'info-rating-side');
      const visits = fountain.rating_count || 0;
      if (fountain.avg_rating !== null && fountain.avg_rating !== undefined) {
        const average = el('div', 'info-average', 'Average ');
        average.append(el('strong', '', formatAverage(fountain.avg_rating) + '/10'),
          document.createTextNode(' from ' + visits + (visits === 1 ? ' visit' : ' visits')));
        side.append(average);
      }
      const post = buildPostLink(fountain);
      if (post) {
        side.append(post);
      }
      ratingRow.append(latest, side);
      info.append(ratingRow);
    } else if (fountain.rating_count) {
      info.append(el('div', 'info-unrated', 'No rating on the latest visit'));
    }

    // Open issue (maintenance only; seasonal and closed are details)
    if (fountain.issue_reported_at) {
      const issue = 'Issue reported ' + formatDate(fountain.issue_reported_at) + (fountain.issue_note ? ': ' + fountain.issue_note : '');
      info.append(el('div', 'info-issue', issue));
    }

    // Actions sit at the top so they are reachable without scrolling past the reviews
    info.append(buildActions(fountain));
    info.append(buildDetails(fountain));

    // Reviews: every approved review, newest visit first
    if (fountain.rating_count) {
      const reviews = el('section', 'info-reviews');
      const heading = el('div', 'info-reviews-head');
      heading.append(el('h3', 'info-reviews-title', 'Reviews'),
        el('span', 'info-reviews-count', fountain.rating_count + ' \u00B7 newest first'));
      const list = el('div', 'info-review-list');
      list.append(el('div', 'info-reviews-note', 'Loading reviews\u2026'));
      reviews.append(heading, list);
      info.append(reviews);
      loadReviews(fountain, list).then(() => {
        if (onVisitsLoaded) {
          onVisitsLoaded();
        }
      });
    }

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
   * details, each Yes / No / Unknown; the season (year-round or seasonal,
   * with its note); and Closed when set.
   */
  function buildDetails(fountain) {
    const details = el('div', 'info-details');
    const addDetail = (label, value, wide) => {
      const item = el('div', wide ? 'info-detail wide' : 'info-detail');
      item.append(el('span', 'info-detail-label', label + ' '), el('strong', '', value));
      details.append(item);
    };

    addDetail('Bottle filler', yesNoUnknown(fountain.bottle_filler));
    addDetail('Accessible', yesNoUnknown(fountain.wheelchair_accessible));
    addDetail('Pet friendly', yesNoUnknown(fountain.pet_friendly));
    if (fountain.indoor === 'Yes') {
      addDetail('Indoor', 'Yes, may be locked outside opening hours', true);
    } else {
      addDetail('Indoor', yesNoUnknown(fountain.indoor));
    }

    if (fountain.operational_status === 'closed') {
      addDetail('Status', 'Closed', true);
      if (fountain.season_note) {
        addDetail('Note', fountain.season_note, true);
      }
    } else {
      addDetail('Season', seasonText(fountain), true);
    }
    return details;
  }

  /**
   * reads the approved reviews and fills the list, one card per review.
   */
  async function loadReviews(fountain, list) {
    try {
      const reviews = await FountainData.fetchReviews(fountain.supabase_id);
      list.replaceChildren(...reviews.map(buildReviewCard));
    } catch (error) {
      console.warn('could not load reviews', error);
      list.replaceChildren(el('div', 'info-reviews-note', 'Could not load the reviews right now.'));
    }
  }

  /**
   * one review: rating chip, who, and date on one line; the text beneath,
   * cut to a few lines with "Read more" when it is long.
   */
  function buildReviewCard(review) {
    const card = el('article', 'info-review');

    const top = el('div', 'info-review-top');
    const rating = formatRating(review.rating);
    if (rating) {
      top.append(el('span', review.author_type === 'admin' ? 'info-review-rating ours' : 'info-review-rating', rating + '/10'), ' ');
    }
    // the spaces keep the parts apart for screen readers; the layout ignores them
    const who = el('span', 'info-review-who', reviewerName(review));
    const post = review.author_type === 'admin' ? safeUrl(review.instagram_url) : null;
    if (post) {
      const link = el('a', 'info-review-post', 'see post');
      link.href = post;
      link.target = '_blank';
      link.rel = 'noopener';
      who.append(' ', link);
    }
    top.append(who, ' ', el('span', 'info-review-date', formatDate(review.visit_date)));
    card.append(top);

    if (review.review_text) {
      const text = el('div', 'info-review-text', review.review_text);
      card.append(text);
      if (isLongReview(review.review_text)) {
        text.classList.add('clamped');
        const more = el('button', 'info-review-more', 'Read more');
        more.type = 'button';
        more.addEventListener('click', () => {
          const clamped = text.classList.toggle('clamped');
          more.textContent = clamped ? 'Read more' : 'Show less';
        });
        card.append(more);
      }
    }
    return card;
  }

  // roughly more than the five lines a clamped review shows
  function isLongReview(text) {
    return text.length > LONG_REVIEW_CHARACTERS || text.split('\n').length > 5;
  }

  function reviewerName(review) {
    if (review.author_type === 'admin') {
      return '@yvrwaterfountains';
    }
    return review.reviewer_name || 'Anonymous';
  }

  /**
   * Review this fountain across the full width, then two equal buttons for
   * telling us about a problem, each with what it is for written beneath.
   */
  function buildActions(fountain) {
    const review = el('a', 'info-btn primary', 'Review this fountain');
    review.href = fountain.supabase_id ? 'review.html?fountain=' + encodeURIComponent(fountain.supabase_id) : 'review.html';

    const problems = el('div', 'info-problems');
    problems.append(
      buildProblemButton('Report an issue', 'Needs fixing: no water, low pressure, leaking or dirty', mailtoLink('Issue at', fountain)),
      buildProblemButton('Suggest a correction', 'Our info is wrong: off for winter, wrong spot or details', mailtoLink('Correction for', fountain))
    );

    const wrap = el('div', 'info-actions');
    wrap.append(review, problems);
    return wrap;
  }

  function buildProblemButton(label, meaning, href) {
    const item = el('div', 'info-problem');
    const button = el('a', 'info-btn secondary', label);
    button.href = href;
    item.append(button, el('div', 'info-problem-meaning', meaning));
    return item;
  }

  function mailtoLink(subjectStart, fountain) {
    const name = fountain.name || 'a fountain';
    const body = 'Fountain: ' + name + '\r\nID: ' + (fountain.id || '') + '\r\n\r\nWhat we should know:\r\n';
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
      colorBar.className = 'sheet-color-bar kind-' + markKind(fountain);
    }

    dom.bottomSheetContent.replaceChildren(buildFountainInfo(fountain));
    dom.bottomSheet.scrollTop = 0;
    dom.bottomSheet.classList.add('active');
    dom.overlay.classList.add('active');
    setBackgroundLocked(true);
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
    setBackgroundLocked(false);
    state.currentFountain = null;
  }

  /**
   * while the sheet is open, the page and the map behind it must not move,
   * so a swipe on the sheet scrolls the sheet.
   */
  function setBackgroundLocked(locked) {
    // iPhone Safari ignores overflow: hidden on the page for touch scrolling,
    // so the page is pinned in place (position: fixed) and put back on close
    const body = document.body;
    if (locked && !body.classList.contains('sheet-open')) {
      state.pageScrollY = window.scrollY;
      body.style.top = '-' + state.pageScrollY + 'px';
      body.classList.add('sheet-open');
    } else if (!locked && body.classList.contains('sheet-open')) {
      body.classList.remove('sheet-open');
      body.style.top = '';
      window.scrollTo(0, state.pageScrollY || 0);
    }

    const handlers = [state.map.dragging, state.map.touchZoom, state.map.doubleClickZoom, state.map.scrollWheelZoom];
    handlers.forEach((handler) => {
      if (handler) {
        if (locked) {
          handler.disable();
        } else {
          handler.enable();
        }
      }
    });
  }

  // ---------------------------------------------------------------------
  // Helpers (don't normally edit)
  // ---------------------------------------------------------------------

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

  // 8 -> '8', 7.5 -> '7.5' (to the nearest half point); no rating -> ''
  function formatRating(value) {
    if (value === null || value === undefined || value === '') {
      return '';
    }
    const number = Math.round(Number(value) * 2) / 2;
    if (!Number.isFinite(number)) {
      return '';
    }
    return Number.isInteger(number) ? String(number) : number.toFixed(1);
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

  // anti_freeze Yes = on all year, No = off in winter. The season note
  // (e.g. "about May to October") is added for seasonal fountains.
  function seasonText(fountain) {
    if (fountain.anti_freeze === 'Yes') {
      return 'Year-round';
    }
    if (fountain.anti_freeze === 'No' || fountain.operational_status === 'seasonal') {
      return fountain.season_note ? 'Seasonal (' + fountain.season_note + ')' : 'Seasonal';
    }
    return 'Unknown';
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
