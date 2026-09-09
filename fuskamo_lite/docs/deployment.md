# Deployment

## One-time setup
```bash
cd fuskamo_flutter
flutter create . --platforms=android,ios --org com.fuskamo --project-name fuskamo
flutter pub get
```
Then fill in `.env` with your real Supabase URL/anon key (copy from `.env.example`).

## Android — Google Play
1. `flutter build appbundle --release`
2. Sign with a real keystore (generate once, store securely — see `release/README.md`, never commit it).
3. Upload the resulting `.aab` from `build/app/outputs/bundle/release/` to the Play Console.

## iOS — App Store
1. Requires a Mac with Xcode.
2. `flutter build ios --release`
3. Archive and upload via Xcode or `xcodebuild`/Transporter, following Apple's normal signing/provisioning flow.

## Backend
Deploy `/backend` as a container to any host that runs Docker images (Render, Railway, Fly.io):
```bash
docker compose up --build   # local test first
```
Push the same image to your host of choice, set the env vars from `backend/.env.example` in its dashboard (never commit `.env`), and point `MPESA_CALLBACK_URL` at the deployed URL's `/api/mpesa/callback`. Then set `BACKEND_BASE_URL` + `BACKEND_API_KEY` in the Flutter app's `.env` to match.

Also make sure every file in `database/migrations/` has been run against your Supabase project, in numeric order (001 through 014) — see docs/admin-access.md for the SQL Editor workflow.
