# Frontend Refactor Plan

## Target file layout
```
/public
  map.html
  table.html
  review.html
  admin.html
  styles.css
/src
  supabaseClient.js
  api.js
  map.js
  table.js
  review.js
  admin.js
  ui.js
```

## Shared UI helpers (`src/ui.js`)
- `qs(selector, root=document)` – lightweight query helper that returns the first match
- `on(element, event, handler, options)` – shorthand for `addEventListener`
- `toast(message, type = 'info')` – renders a floating notification panel
- `showSpinner(container)` / `hideSpinner(container)` – attach and remove a reusable loading spinner
- URL helpers: `getParam(key)`, `setParam(key, value)`, `getAllParams()`
- helpers should export plain functions and also register them on `window.AppUI` for backwards compatibility with inline scripts

## Event flow diagrams

### Map view
1. **page load** → DOM ready event triggers `map.init()`
2. `map.init()` → request shared client from `api.getSupabaseClient()`
3. client available? **yes** → `api.fetchFountains()` pulls `fountain_overview_view`, otherwise falls back to bundled GeoJSON
4. data resolved → `map.renderMarkers()` adds Leaflet markers to the map layer
5. marker click → `map.showPopup()` uses shared template helper to render fountain details

### Public review submission
1. user fills review form → hits submit button
2. form handler → validates input with shared helpers → shows loading spinner
3. handler calls `api.insertPendingReview(formData)` → writes to `reviews` table with `status='pending'`
4. promise resolves → spinner removed → `toast('thanks for sharing!')`
5. form fields reset → optional map focus cleared

### Admin moderation flow
1. admin visits `/public/admin.html` → sees login panel
2. login form submit → `api.signInWithPassword()` authenticates against Supabase
3. after auth → `admin.loadPending()` fetches `reviews` with `status='pending'`
4. admin chooses approve/reject → `api.moderateReview(id, action)` writes to base table
5. panel refreshes list → toast shows result (approved/rejected)
