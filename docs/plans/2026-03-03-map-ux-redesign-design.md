# Map & UX Redesign — Design Doc

**Date:** 2026-03-03
**Scope:** `map.html` only (the public-facing page). Admin pages untouched.

---

## Goal

Retheme the map page with a y2k-inspired aesthetic matching the @yvrwaterfountains sticker branding, improve map UX (dot sizing, popups, bottom sheet), show Instagram caption text in popups, and add a shared CSS theme file for future page reuse.

## Visual Identity

### Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| Primary | `#c8ff00` | Header bg, rating badges, admin-reviewed dots, CTA buttons |
| Secondary | `#ff69b4` | Instagram links, community-reviewed dots, action buttons |
| Tertiary | `#7eb6ff` | Unreviewed dots, accent highlights |
| Accent | `#c5a3ff` | Info section borders, subtle highlights |
| Dark | `#1a1a2e` | Text, footer bg, dot outlines, nav pills |
| Light | `#f5f0ff` | Info section backgrounds, caption boxes |

### Typography

- **Header title:** Bungee Shade (Google Fonts) — retro arcade y2k feel
- **Subtitle:** Quicksand 600 weight (Google Fonts) — rounded, modern complement
- **Popup/sheet titles:** Fredoka One (Google Fonts) — bubbly but readable
- **Body text:** System font stack (unchanged) — fast, clean for data

### Logo & Favicon

- Header logo: `docs/images/logo.png` (the green starburst sticker)
- Favicon: Derived from `logo.png` (resized to 32x32)
- Both reference the bottom-middle sticker design

## Header

- Neon lime (`#c8ff00`) background
- Logo image (48x48, rounded corners) + "YVR WATER FOUNTAINS" in Bungee Shade
- Subtitle: "where to hydrate in Vancouver" in Quicksand
- Nav pills: "Submit Review", "My Location", "@yvrwaterfountains" (IG link, outlined style)
- Admin link moved to footer (dimmed, unobtrusive)
- Compact on mobile (smaller font, stacked layout)

## Map Markers

- **Shape:** Circle dots (not water drops)
- **Size:** Scale with zoom level — smaller when zoomed out, larger when zoomed in
- **Colors:** Neon lime (admin), hot pink (community), sky blue (unreviewed)
- **Outline:** `#1a1a2e` (dark) border on all dots, uniform
- **Same size** for all three types

## Desktop Popups

- White card with rounded corners + colored top border (lime/pink/blue matching dot type)
- Fountain name in Fredoka One, clickable (hover → pink)
- Info section: light lavender background (`#fafbff`) with left lavender border
- Rating shown in neon lime pill badge
- Instagram caption text shown in italic lavender box (scrollable if long)
- Instagram link in hot pink
- Photo thumbnail (when available) floated right
- Unreviewed fountains: "Be the first to review!" CTA button (solid lime)

## Mobile Bottom Sheet

- Solid color bar at top matching dot type (lime for reviewed, blue for unreviewed)
- Drag handle
- Photo thumbnail next to title (when available)
- Fountain name in Fredoka One + subtitle with neighbourhood/location
- Rating badge (lime pill)
- Info section with lavender background + left border (matching desktop)
- Instagram caption text in lavender box
- Action buttons at bottom: "View on Instagram" (pink) + "Submit Review" (light)
- Unreviewed: no photo, single "Be the first to review!" CTA

## Footer

- Dark navy (`#1a1a2e`) background
- Links: @yvrwaterfountains, Submit a Review, GitHub, Admin (dimmed)
- Credit line: "Built by kcarbeck" linking to GitHub profile
- Links in neon lime, hover → pink

## Shared Theme File

Create `docs/css/theme.css` containing:
- CSS custom properties (color variables)
- Google Fonts imports
- Reusable classes: rating badge, info section, caption box, nav pills, footer
- Map page imports it; future pages (review form etc.) can import it too

## Instagram Caption Display

- The `instagram_caption` field from the reviews table is already stored
- Show it in popups/bottom sheets for reviewed fountains
- Truncate to ~200 chars in popup, scrollable in bottom sheet
- Styled as italic text in a lavender rounded box

## What This Does NOT Include

- Admin page restyling (deferred to when public review form is built)
- Instagram photo oEmbed (deferred — requires API key or separate photo_url column)
- Map tile styling changes
- The preview_theme.html file will be deleted after implementation
