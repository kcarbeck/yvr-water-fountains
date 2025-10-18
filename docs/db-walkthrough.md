# Database Walkthrough

This guide explains the Supabase structure that powers the fountain map so you can see how data flows from Postgres into the public site and the admin moderation tools.

## Core tables

- **cities** — one row per municipality we cover. The `id` is a UUID and every fountain references it. Add a row if we start tracking a new city.
- **sources** — tracks where each fountain record originated (city open data, field survey, etc.). Use the optional `contact_url` for attribution.
- **fountains** — the canonical record for each fountain. Key fields:
  - `city_id` and `source_id` tie back to the lookup tables.
  - `operational` stores the normalized status (`operational`, `seasonal`, or `unknown`).
  - `operational_season` is free text for the seasonal note we show beside the status.
  - `pet_friendly` is the compact flag (`y`, `n`, or `unknown`). Views expand this into human-readable labels.
  - `has_bottle_filler`, `is_wheelchair_accessible`, and `last_verified_at` hold amenity details from our surveys.
  - `is_active` controls whether the public can see the fountain. Row-level security only returns active rows to anonymous visitors.
- **reviews** — both community and admin feedback. The insert trigger enforces:
  - anonymous submissions become `reviewer_type = 'public'`, `status = 'pending'`, and must not include Instagram links.
  - admin-authenticated inserts can set `reviewer_type = 'admin'` and are automatically marked `approved` when `status` is omitted.
  - ratings are integers from 1–10 so we can average them cleanly.
- **admins** — the whitelist of Supabase auth users allowed to moderate reviews. Seed at least one row manually so someone can sign in.

## Supporting views

- **approved_reviews** — convenience view with only approved reviews. Keeps the other views simple.
- **fountain_review_stats** — computes the average rating, total approved reviews, and the number of admin-authored reviews for each fountain.
- **fountain_latest_review** — finds the freshest approved review per fountain, including Instagram metadata when available.
- **fountains_public** — joins `fountains` with the stats and latest review views plus lookup tables so the frontend can grab everything in one call. It also exposes the compatibility view `fountain_overview_view` that the current JavaScript already uses.

## Row-level security policies

- Anonymous visitors (`anon` role):
  - Can read `cities`, `sources`, and `fountains_public`.
  - Can read only approved rows from `reviews`.
  - Can insert into `reviews` when the payload stays within the trigger guardrails (public reviewer, no Instagram fields).
- Authenticated admins (checked via the `is_admin()` helper):
  - Can select, insert, update, and delete across `reviews`, `fountains`, `cities`, `sources`, and `admins`.
  - Gain extra insert/update powers so they can publish Instagram posts and approve community submissions.
- Admin table entries are hidden from everyone else, which keeps the list of privileged accounts private.

## Public vs. admin flow

1. The map calls `fountains_public`/`fountain_overview_view`. Row-level security only returns active fountains, the average ratings, and the latest approved review.
2. When someone submits a review without logging in, the trigger strips any Instagram fields, forces the review into `pending`, and stores it with `reviewer_type = 'public'`.
3. An admin signs in with email/password. Because their auth UID appears in the `admins` table, the policies let them insert admin reviews (auto-approved) and update community reviews to `approved` or `rejected`.
4. Once a review is marked `approved`, it surfaces automatically in `approved_reviews`, flows into the aggregate views, and appears on the map after the next fetch.

## Approving a pending review

1. Sign in through the moderation dashboard with a Supabase account listed in `admins`.
2. Locate the pending review in the queue and inspect the submission details.
3. Click **Approve** to set `status = 'approved'`. The frontend sends the update through `reviews_update_admin`, which the policy allows because the user is an admin.
4. Refresh the public map to confirm the latest review snippet updated for that fountain.

![screenshot placeholder – approving a pending review in the moderation dashboard](images/approve-review-placeholder.png)

Follow these steps every time you approve or reject community feedback so the database stays consistent with what the public sees.
