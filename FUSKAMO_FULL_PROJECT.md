# FUSKAMO — Full Project Package

This package contains the current FUSKAMO application stack plus the upgraded web and Lite UI designs.

## Main production application
- `lib/` — Flutter application source
- `android/` — Android project
- `ios/` — iOS project/setup
- `backend/` — Node/Express privileged API
- `database/` — Supabase/Postgres schema and migrations
- `api/` — OpenAPI contract
- `assets/` — app assets/icons
- `test/` — Flutter tests
- `docs/` — architecture, deployment, security and operations docs
- `admin-web/` — administrator console

## Web app
- `web-app/` — existing wired web application
- `web-app-redesign/` — new Talent Command / Talent Radar visual redesign

The redesign is kept separate so the existing wired web app is not accidentally broken while the new UI is integrated.

## Lite app
- `fuskamo_lite/` — complete separate Flutter Lite project with its own backend/database/docs
- `lite-ui-redesign/` — lightweight web/mobile UI prototype for the new Lite experience

## Configuration
Copy `.env.example` to `.env` and fill in your own Supabase/backend values. Never commit real credentials.

For the Flutter app, the backend architecture is Supabase for ordinary RLS-constrained reads/writes and the custom backend for privileged operations such as M-Pesa and AI services.

## Important
The package intentionally does not contain real secrets. Some production integrations require your own provider credentials and deployment configuration before they can run.
