# Changelog

## [Unreleased]
- extracted the map logic into `docs/js/map.js` to simplify maintenance and keep sensitive behavior easier to audit.
- deleted the legacy table view, quarantine folder, exploratory notebook, and credential-printing tests after confirming they were unused.
- removed the temporary planning documents now that the deletion review is complete.
- documented the supabase-first architecture plan in `docs/adr-001-architecture.md` so future work stays aligned.
- implemented the normalized supabase schema, backfill script, and rls policies so the map, forms, and moderation dashboard use live data with safe defaults.
- rebuilt the admin review form and moderation dashboard to rely on supabase auth, surfacing pending reviews and approving updates directly from the browser.
