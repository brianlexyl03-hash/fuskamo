# FUSKAMO — implementation and launch blockers

This file distinguishes working repository assets from integrations that cannot be honestly marked complete without implementation, provider access or verification.

## Product parity and architecture

| Area | Current repository evidence | Blocker / minimum viable path |
|---|---|---|
| Native app | Flutter application under `lib/` and Android project | Instagram-grade parity across all requested story, feed, reel, DM, search and creator workflows requires feature-by-feature implementation, shared data contracts, migrations, tests and device QA. Do not infer parity from existing screens. |
| Public web app | `web-app/` is a static HTML/CSS/JavaScript client | The master build prompt specifies Next.js App Router, TypeScript strict mode, Tailwind, Radix, TanStack Query and Zustand. This is an architectural migration, not a small cleanup. Choose and implement a migration plan while preserving the current deployed client until replacement passes acceptance tests. |
| Admin console | Separate `admin-web/` app | Must be regression-tested against the evolving user/content moderation model and RLS policies. |
| Shared feature parity | Three separate app surfaces | Define shared API contracts and acceptance tests, then implement and verify each surface independently. |

## External services and credentials

| Feature | Missing dependency or verification | Minimum viable path |
|---|---|---|
| Live Rooms / WebRTC | LiveKit project URL, API key/secret, deployment, webhook configuration, moderation and load tests | Configure LiveKit in a server-only environment, add token issuance and room lifecycle APIs, then test multi-participant sessions on real devices. |
| Background media processing and HLS | Production Redis/Upstash, BullMQ workers, FFmpeg runtime and video delivery provider/storage signing | Deploy workers and queue, implement retry/idempotency, thumbnails/transcodes/HLS and signed playback, then validate large uploads and failure recovery. |
| Instagram discovery | Meta developer app, approved permissions/use case, OAuth flow and any required App Review | Use only Meta-approved APIs for the permitted account/content scope. Instagram APIs do not provide unrestricted access to search all Instagram users or scrape arbitrary profiles. Build a human-reviewed lead workflow from authorised public signals and opt-in submissions. |
| Reddit discovery | Reddit application registration, OAuth client credentials, approved API access and rate-limit policy | Use Reddit's official API for permitted public subreddit/search data, store only necessary post references and context, and require human review before outreach. Do not scrape Reddit pages or automate unsolicited DMs. |
| Push notifications | Firebase project configuration and platform-specific credentials; APNs setup for iOS | Configure FCM/APNs credentials, test permission flows and delivery on physical devices, and verify notification preferences and token deletion. |
| Email/SMS | Production provider credentials, verified sender/domain, delivery webhooks and opt-out policy | Configure provider credentials in server secrets, verify domain/sender and test bounce, retry and opt-out handling. |
| Payments | Live merchant credentials, callback URLs, reconciliation and refund procedures | Complete provider onboarding and run sandbox-to-production verification before enabling real charges. |
| AI services | Provider selection, API credentials, retention and data-processing review | Enable only after documenting data sent to the provider, retention, consent and user-facing disclosure. |

## Legal, privacy and safeguarding

- Confirm the exact registered legal entity name, registration number and service address.
- Confirm a monitored privacy contact and implement an operational data-access/deletion request process.
- Complete a data inventory of every SDK, analytics event, provider, database table and retention schedule.
- Set minimum-age and parental-consent controls for each launch jurisdiction.
- Adopt a child-safeguarding and adult-to-minor contact policy with escalation procedures.
- Have qualified counsel review the Privacy Policy, Terms, payments, consumer rights and cross-border processing.
- Publish concrete retention periods after backup and transaction retention are verified.

## Release verification

Before calling the platform production-ready, run Flutter analysis/tests, backend tests, web checks, migration/RLS tests, Playwright flows for the web client, device tests on Android and iOS, upload/processing tests, permission tests, accessibility checks and load tests. Capture the actual CI run and environment used. A test that was not run is not a passing test.
