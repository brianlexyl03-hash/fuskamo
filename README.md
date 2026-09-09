# FUSKAMO

Global football talent discovery platform. FUSKAMO connects players — from any village, any estate, any country — with verified scouts and agents. Built as a **native Flutter application** (Android + iOS, one Dart codebase) for Google Play Store / App Store release. No WebView, no HTML/CSS/JS in the shipped app.

Built by FUSKAMO NPC.

## Setup before this runs

`android/` is already committed and configured in this repo (signing
config, manifest permissions, `applicationId com.fuskamo.fuskamo`) — do
**not** run `flutter create .` for Android, it would overwrite that
configuration. Just run:

```bash
flutter pub get
```

`ios/` has **not** been generated or committed yet (see "Genuinely still
open" below) — when you're ready for an iOS build, on a Mac with Xcode
installed, generate only that platform so Android is untouched:

```bash
flutter create . --platforms=ios --org com.fuskamo --project-name fuskamo
```

Then copy `.env.example` to `.env` and fill in your Supabase URL/anon key, plus your deployed backend URL/key.

Also start the custom backend (M-Pesa, AI, privileged operations):
```bash
cd backend
cp .env.example .env   # fill in Supabase service role key, M-Pesa + AI credentials
npm install
npm run dev
```
See `backend/README.md` for the full architecture reasoning and endpoint list.

## What's built

- [x] Full Flutter app: 14 real screens (Feed, Discover, Search, Upload, Scouts, Scout apply, Profile/account, Notifications, Notification preferences, MFA setup, MFA challenge, Video player, Region detail, root shell/nav) — not a WebView
- [x] Typed models (`Player`, `Scout`, `Region`) — no hardcoded personal data anywhere
- [x] Supabase integration via services/repositories/providers (Provider state management)
- [x] Player submission form with optional video attach (Supabase Storage)
- [x] Design system ported 1:1 from the original pitch-themed prototype (`lib/theme/`, `lib/constants/`)
- [x] go_router navigation, bottom nav
- [x] App icon (`assets/icons/`) — generated from the user-provided FUSKAMO logo design; source was 256×256, upscaled for the 512×512 sizes (Play Store listing, maskable), so re-supply a higher-res source if that upscale looks soft at full size
- [x] Custom backend (`/backend`) — real Express app: M-Pesa STK Push + callback + admin-triggered refunds, AI player-summary endpoint, live country list, notification dispatch (SMS/email/push)
- [x] Auth — real Supabase email/password accounts with email verification enforced in-app (`lib/providers/auth_provider.dart`), optional TOTP MFA (`lib/screens/mfa_setup_screen.dart`, `mfa_challenge_screen.dart`)
- [x] Push notifications — real FCM wiring (`lib/notifications/push_notification_service.dart`); still needs a Firebase project's credentials before it can actually send anything, see `docs/push-notifications-setup.md`
- [x] Email and SMS notification channels — real Africa's Talking (SMS) and SMTP (email) integration (`backend/src/email/`, `backend/src/notifications/smsService.js`), wired into player approve/reject/feature events, gated by each user's own notification preferences. In-app notifications also work via Supabase Realtime.
- [x] Localisation — real EN/Swahili toggle (`lib/localisation/`)
- [x] Connectivity-aware offline banner (`lib/network/connectivity_service.dart`, `lib/widgets/offline_banner.dart`)
- [x] Video playback in-feed (`lib/screens/video_player_screen.dart`)
- [x] Search across players and scouts (`lib/screens/search_screen.dart`)
- [x] Real contact (email/WhatsApp/call — `lib/helpers/contact_launcher.dart`), saved players, M-Pesa "boost submission" payment flow
- [x] Admin system — a separate console (`admin-web/`), not a screen inside this app. Every administrator has their own Supabase Auth account, a role, and granular permissions (Super Admin / Admin / Moderator / Support, or custom roles) — no shared key anywhere. Covers player/scout approval, transactions, a full audit log (who/when/from where), MFA, session management, and Super-Admin account lifecycle management. See `docs/admin-access.md`.
- [x] Scout application flow (`lib/screens/scout_apply_screen.dart`)

Architecture, end to end:

```
Flutter app
    ↓
Supabase (auth, database, storage, RLS)
    ↓
Custom backend (M-Pesa, AI, notifications)
    ↓
admin-web/ (separate console, its own Supabase Auth accounts + RBAC)
```

## Genuinely still open

- [ ] Threaded in-app messaging (current "Contact" is real but hands off to email/WhatsApp/phone — there's no message history inside the app itself)
- [ ] Live per-region player counts on Discover (currently shows country-count per region, not a live player tally)
- [ ] Virus scanning on uploaded video clips (`backend/src/uploads/virusScan.js` — needs a ClamAV instance, deliberately left unimplemented rather than faked)
- [ ] iOS build — the `ios/` native project folder hasn't been generated/committed yet; Android is the current target
- [ ] `backend/package-lock.json` isn't committed yet — the Dockerfile uses `npm install` rather than `npm ci` until one exists (run `npm install` once with network access from `backend/`, then commit the generated lockfile and switch the Dockerfile back to `npm ci` for reproducible builds)

## Project structure

See the full annotated tree in `docs/architecture.md`. Short version: `lib/` is organized by responsibility (screens, widgets, providers, repositories, services, models) — every screen from the original prototype has a matching Flutter screen, every reusable UI piece is a widget, every Supabase call lives in `services/`.

## Docs

`docs/` covers architecture, API, database, deployment (Play Store + App Store), security, testing, and a user guide.

## License

See `LICENSE`.
