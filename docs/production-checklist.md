# Production checklist — everything left before a public launch

**This round: admin authentication was fully reworked.** The old shared
`ADMIN_API_KEY` is gone from every file in this repo — replaced with real
per-admin Supabase Auth accounts, roles, granular permissions, MFA, and
session management. Run `database/migrations/013_admin_rbac.sql`, deploy
`admin-web/`, and see `docs/admin-access.md` for the one-time first-Super-
Admin setup step (needs a manual SQL insert, everything after that is
UI-driven).

This replaces any older "Phase 2" notes you may have seen (README.md and
CHANGELOG.md previously said auth/push/localisation/connectivity were
still deferred — they're not, as of this checklist; corrected there too).
As of this round, the only things left are values only you can supply
(real credentials, a Firebase project) — every placeholder document and
every orphaned code path found in a full repo sweep has been fixed or
wired in.

## 0. Signing — done this round
- No production keystore is shipped in this repository. Generate your own
  Android upload keystore and create `android/key.properties` from
  `android/key.properties.example`. Never commit either file.
- `android/app/build.gradle.kts` now reads `key.properties` and signs
  release builds with it; falls back to debug signing (with a code
  comment) only if `key.properties` is missing, so the project still
  builds if you haven't added it yet.
- **Google Play now manages your actual signing key (Play App Signing)
  once you upload — this `.jks` is your *upload* key.** Keep it and its
  password safe regardless; losing it before first upload means starting
  over on the listing.

## 1. Values you must supply via `.env`

### Flutter app root `.env` (copy from `.env.example`)
| Variable | What it's for | Public build safe? |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Direct Supabase access (feed, scouts, auth, storage) | Yes |
| `BACKEND_BASE_URL`, `BACKEND_API_KEY` | Your deployed `/backend` — M-Pesa, AI summaries | Yes |

There's no admin config in this app anymore — admin review is a separate
app, `admin-web/`, with its own per-admin Supabase Auth accounts. See
`docs/admin-access.md`.

### Backend `backend/.env` (copy from `backend/.env.example`)
| Variable | What it's for |
|---|---|
| `BACKEND_API_KEY` | Must match the Flutter app's value above |
| `ADMIN_CONSOLE_URL` | Where `admin-web/` is deployed — used as the default redirect for admin-invite emails. Optional, fill in once you've deployed `admin-web/` |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `SUPABASE_DB_URL` | Privileged Supabase access (approve/reject, boost payments, notifications) |
| `MPESA_CONSUMER_KEY`, `MPESA_CONSUMER_SECRET`, `MPESA_SHORTCODE`, `MPESA_PASSKEY`, `MPESA_CALLBACK_URL` | Boost-payment STK push. Safaricom Daraja portal. `MPESA_CALLBACK_URL` must be your live deployed URL, not localhost |
| `MPESA_INITIATOR_NAME`, `MPESA_SECURITY_CREDENTIAL` | Only needed if you ever add refunds (B2C) — not used by anything currently in the app |
| `AI_PROVIDER_API_KEY`, `AI_MODEL`, `AI_PROVIDER_BASE_URL` | Powers "Preview AI scouting note" on submission |
| `AT_USERNAME`, `AT_API_KEY` | SMS (Africa's Talking) — service is implemented and now wired into player approve/reject/feature notifications (`playerAdminRepository._notifyContact`), gated on the user's `sms_enabled` preference and a `contact_phone` on the submission. Setting these env vars is all that's left |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `EMAIL_FROM` | Email — same fix, same method, gated on `email_enabled` + `contact_email` |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | For the backend to actually *send* pushes via FCM — **declared but not wired to any code path yet.** The Flutter side (device token storage) is done; the "send a push" half is a backend addition not built yet |
| `REDIS_URL`, `CORS_ALLOWED_ORIGINS` | Optional — rate limiting / CORS lockdown |

### Firebase (files, not env vars)
- `android/app/google-services.json` — download from your Firebase project once you make one. Full steps in `docs/push-notifications-setup.md`
- iOS equivalent (`GoogleService-Info.plist`) doesn't apply yet — no iOS build

## 2. Legal docs — filled in this round
- `legal/privacy-policy.md`, `legal/terms.md` — legal entity set to `Lexil N.P.C.`,
  contact set to `brianlexyl03@gmail.com`, governing law set to `Kenya`,
  last-updated date set to today. **Review the wording yourself** — I
  filled in the identity fields, not a lawyer's judgment on the
  substance, and neither of us is one.
- `security/policies/data-handling.md` — still references
  `js/supabase-client.js`, a leftover from the pre-Flutter web prototype
  that doesn't apply anymore; harmless but worth deleting that line.

## 3. Intentionally unimplemented (not bugs — documented in the code itself)
- `backend/src/uploads/virusScan.js` — needs a running ClamAV instance; the function throws on purpose rather than pretending to scan. This is genuinely not fixable without you standing up that infrastructure — no code change substitutes for it
- `docs/csrf-decision.md` — CSRF protection deliberately skipped; the doc explains why it doesn't apply to this architecture (native app + bearer token, no browser cookies involved)
- `backend/src/routes/auth.routes.js` — intentionally thin (one endpoint, token refresh proxy); Supabase Auth's own client handles the rest directly from Flutter

## 4. Android — fixed this round
- Restored the native `android/` project (was entirely missing before)
- Release manifest was missing `INTERNET`/`ACCESS_NETWORK_STATE` permissions and package-visibility `<queries>` for mailto/tel/https — added, see the comments in `AndroidManifest.xml`
- App icons: using the set from your earlier project (`assets/icons/`) rather than generating new placeholder ones

## 5. iOS — not started
No native `ios/` project exists yet (no Xcode project, Info.plist, etc.) — skipped for now per your call. Needs a Mac to generate and build regardless of what's in this repo.

## 6. Account lockout — a Supabase project setting, not app code
Supabase Auth already rate-limits sign-in/sign-up attempts by IP (token-bucket, defaults to bursts of 30). Turn on/tighten it and add CAPTCHA at **Supabase Dashboard → Authentication → Configuration → Rate Limits** (and **Auth → Attack Protection** for CAPTCHA). Building a second, weaker lockout system in this app's own code would just duplicate what Supabase already does, and worse.

## 7. Added this round
- **Two-factor authentication** — real TOTP via Supabase Auth MFA (Profile → Two-factor authentication): QR enrollment, 6-digit challenge at sign-in, disable flow
- **Admin audit log dashboard** (6th admin tab) — every approve/reject now records who/what/when; previously the audit infrastructure existed but nothing called it
- **Notification preferences** (Profile → Notification preferences) — the push toggle has a real effect on device token registration; email/SMS toggles now actually gate real sends (see §1) once you set AT_*/SMTP_* env vars
- **Advanced search filters** — position and age range, usable with or without a name typed
- **Rate limiting on the AI endpoint** — previously only M-Pesa had the tighter per-minute limiter, despite AI also costing money per call

## 8. Real bugs found and fixed while building the above
- `playersAdminController.js` returned pending players under a `data` key; the Flutter admin Players tab read `players` — a guaranteed crash the first time anyone opened it, now fixed
- Migration 011 tried to recreate a scouts RLS policy migration 001 already made — would have failed outright on a fresh database
- The submit form's country field was free text; a real `/external/countries` endpoint existed for exactly this and was never called, so inconsistent country spelling could silently break Discover's region filtering — now wired to a live autocomplete

## 9. Repo-wide placeholder sweep — done this round
Grepped every `.md`/`.js`/`.dart`/`.yaml`/`.json` file for `[DATE]`, `[ ]`,
`TBD`, `lorem ipsum`, `changeme`, `example.com`, and similar markers.
Everything found was either fixed above (legal docs) or is a legitimate
checklist/roadmap item, not a stub (`README.md` "not yet built" list,
`docs/testing.md` manual QA checkboxes) — left as-is since those are
accurate descriptions of real future work, not placeholders standing in
for missing code.

**What's left is only things I cannot supply on your behalf:** real
Supabase/M-Pesa/AI/Africa's Talking/SMTP credentials in the two `.env`
files, and a real Firebase project's `google-services.json`. Everything
else that could be fixed with a code or doc change has been.
