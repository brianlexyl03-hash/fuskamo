# Changelog

## Unreleased
- Auth (real Supabase accounts), push notifications (FCM), EN/Swahili localisation, offline-aware caching
- Real Contact (email/WhatsApp/call), saved players, in-feed video playback, search
- M-Pesa "boost submission" payment flow, tied into feed ordering
- Admin review queue (approve/reject players & scouts) and scout application flow — see docs/admin-access.md
- Submissions linked to accounts (`players.submitted_by`) — enables "My Submissions" and per-user notifications
- Android: restored the native `android/` project (was missing entirely), added the INTERNET/ACCESS_NETWORK_STATE permissions and package-visibility `<queries>` the release manifest was missing — see the note in AndroidManifest.xml
- iOS native project not yet generated/committed — out of scope until there's a Mac to build it on

## Flutter rebuild
- Full rebuild from web PWA prototype into native Flutter app
- 5 screens reimplemented as Flutter widgets/screens (no WebView)
- Player/Scout models, Supabase services, repositories, providers
- Design tokens ported from original CSS into lib/theme + lib/constants
- Phase 2 placeholders scaffolded with TODOs: auth, push, localisation, connectivity (since implemented — see Unreleased above)

## Prior web MVP
- See archived web version — PWA shell, Supabase-backed feed/upload/scouts

## Identity + Scoreboard V6
- Canonical, case-insensitive @username policy with reserved names and 30-day change cooldown.
- Follow graph with email-confirmation and block-aware anti-gaming gates.
- FUSKAMO Scoreboard with Global, role, Rising and Trusted leaderboards.
- Deterministic ranking; no random jitter.
- Score formula separates quality, trust, recognition, followers, awards, momentum and profile completeness.
- Public profile now exposes score, awards, follows, likes and direct messaging.
- Removed the misleading automatic black tick from merely approved player cards.

## Platform Infrastructure V2
- Added event, feature, ranking, search, experimentation, safety, media, analytics, realtime, reliability and observability infrastructure contracts.
- Added migrations 028-029 for platform intelligence, reliability, security, experimentation, telemetry and disaster recovery state.
- Added platform-intelligence backend routes and tests.
- Preserved video as an explicit Coming Soon capability until real storage/CDN infrastructure is provisioned.
