# FUSKAMO Web App

User-facing FUSKAMO web client, separate from `admin-web`.

## Run locally

1. Copy `config.example.js` to `config.js` and set the public Supabase URL and anon key.
2. Serve this directory with a local static server. Opening `index.html` directly may block browser network and storage behavior.
3. Sign in with a test account and validate the social areas against a staging Supabase project before production.

The root `.env.example` and `backend/.env.example` are intentionally committed templates. Copy them to local ignored `.env` files and replace placeholders locally. Do not commit real `.env` files or server-only secrets. The browser uses only the public Supabase anon key; never put a service-role key, database URL, JWT secret or payment secret in browser code.

## Night Match visual system

The redesign uses an original football / stadium direction: carbon-black surfaces, chalk typography, restrained pitch-lime accents and oxidized-orange action color. The reference benchmark was Call of Duty: Mobile's use of dramatic hero artwork, a dark stage, high-contrast typography and image-led content sections; FUSKAMO does not copy its logos, characters or artwork.

The opening sequence is an interactive CSS 3D stadium tunnel with staged lighting, curtain reveal and a football moving through perspective. It can be skipped, exits automatically, and respects reduced-motion preferences. In-app route changes use perspective transitions with spring-damped pointer parallax on capable desktop devices. The welcome/auth scene and feed masthead use real Pexels football/stadium photography:
- Stadium photograph by Siarhei Nester: https://www.pexels.com/photo/illuminated-soccer-stadium-at-night-28827841/
- Match-action photograph by Mahammad Shamilov: https://www.pexels.com/photo/soccer-player-running-in-field-14445158/

## Reels and social interactions

- Recommended reels call the existing `get_social_reels` database RPC; Latest uses chronological public reels.
- Reel playback pauses when a clip leaves view, and watch time is reported through the existing view RPC when supported.
- Likes, threaded comments, saves, native sharing/link copying and feedback/report actions use the existing Supabase tables and RPCs.
- Recommendations describe available server-side signals without claiming to replicate Instagram's private ranking system.

## Before production

Run the project checks, exercise login / account creation / password reset, test posting and uploads, validate threaded comments and group membership with real test accounts, and confirm all relevant RLS policies and migrations in staging. Check the cinematic experience on iOS Safari, Android Chrome and desktop, including reduced-motion and slow-image-network behavior. A live authenticated browser session has not been claimed as tested by this design change.
