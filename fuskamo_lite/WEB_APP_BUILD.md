# FUSKAMO Web Client Build

The project now contains two browser clients:

- `web-app/` — the user-facing FUSKAMO web client
- `admin-web/` — the privileged administration console

The user-facing web client shares the same Supabase project and backend configuration concepts as Flutter. It covers the core product navigation: Home/Posts, Discover, Reels, Stories, Groups, Messages, Scoreboard, Universal Search and Profile/Safety. It uses browser-safe Supabase credentials only.

Video hosting remains explicitly disabled until cloud storage/CDN infrastructure is enabled. The Reels experience is present as a product surface and ranking/engagement shell without pretending that large video hosting is live.

Configure `web-app/config.js` from `config.example.js`.
