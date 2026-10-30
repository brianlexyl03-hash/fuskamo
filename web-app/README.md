# FUSKAMO Web App

User-facing FUSKAMO web client, separate from `admin-web`.

## Run locally

1. Copy `config.example.js` to `config.js` and fill in the public Supabase URL and anon key.
2. Serve this directory with a local static server; opening `index.html` directly may block browser module or network behavior.
3. Sign in with a test account and verify the social areas against a non-production Supabase project before deployment.

Never put service-role keys, JWT secrets, database passwords, payment credentials or other server-only secrets in browser configuration. The repository root `.env.example` and `backend/.env.example` are configuration templates; copy them to local ignored `.env` files and replace placeholders locally. Do not commit real `.env` files.

## Social UX refresh

The refresh adds a new light-first violet/mineral-teal visual system, responsive navigation, accessible focus and reduced-motion states, and a dedicated reels experience:
- Recommended reels call the existing `get_social_reels` database RPC; Latest uses chronological public reels.
- Reel playback pauses when a clip leaves view, and view watch-time is reported through the existing RPC when supported.
- Likes, threaded comments, saves, native sharing/link copying and feedback/report actions use existing Supabase tables and RPCs.
- The ranking explanation describes the existing server-side signals at a high level; it does not claim Instagram's private algorithm or imply that the recommendation model was replaced.

## Before production

Validate Supabase RLS and migrations in a staging project, test sign-in and posting flows on mobile and desktop, check browser media permissions, and run the project's CI/build workflows. Reels require the corresponding database migrations and configured storage bucket.
