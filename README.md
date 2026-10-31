# FUSKAMO

**Football talent discovery, player development and community.**

FUSKAMO helps football players present their profiles and work, and helps scouts, coaches, clubs and supporters discover talent and football activity. The repository contains the native mobile app, the public web experience, a separate admin console, backend services and database assets.

**Public website:** https://fuskamo.vercel.app  
**Source:** https://github.com/brianlexyl03-hash/fuskamo  
**Privacy Policy:** [legal/privacy-policy.md](legal/privacy-policy.md)  
**Terms of Service:** [legal/terms.md](legal/terms.md)

> Product scope note: the native app, web app and admin console are separate deliverables. They share the FUSKAMO brand and backend/data services, but they are not currently a single Next.js application. Do not assume that a feature implemented on one surface is automatically implemented on the others.

## Product surfaces

| Surface | Location | Technology | Purpose |
|---|---|---|---|
| Native mobile app | Repository root: `lib/`, `android/`, `ios/` (if generated) | Flutter / Dart | Android and iOS experience |
| Public web app | `web-app/` | Static HTML, CSS and JavaScript | Browser-based user experience |
| Admin console | `admin-web/` | Standalone browser application | Restricted moderation and operational tools |
| API/backend | `backend/` | Node.js / Express | Privileged operations, integrations and service endpoints |
| Database and API contract | `database/`, `combined_migrations.sql`, `api/` | PostgreSQL / Supabase SQL, OpenAPI | Schema, access policies and API reference |

## Main capabilities in the codebase

The project includes account authentication, player and scout profiles, player discovery, social feed and media interactions, groups, messaging screens, notifications, reels/video surfaces, scoreboard and football data, moderation, admin workflows, analytics screens, and payment/backend integrations.

Feature availability and parity vary by platform. A screen or design element is not proof that its backend workflow, security policy, media pipeline or production integration is complete. See [BLOCKERS.md](BLOCKERS.md) for the known integration and parity work that still requires implementation or external credentials.

## Repository map

- `lib/` — Flutter application code: screens, widgets, providers, repositories, services, models, routing, theme and validation.
- `android/` — Android native project and release configuration.
- `ios/` — iOS native project, when generated and maintained.
- `web-app/` — public web client and its styling, runtime and Vercel configuration.
- `admin-web/` — separate administrative web console.
- `backend/` — Express API, authentication/authorization, controllers, repositories, jobs, notifications, media and integrations.
- `database/` — SQL schema and migration assets.
- `api/openapi.yaml` — API contract.
- `docs/` — architecture, setup, operations and product documentation.
- `legal/` — privacy policy, terms and third-party licence notes.
- `.github/workflows/` — CI and release automation.
- `scripts/` — local build, test, backup and restore helpers.

## Getting started

### Requirements

- Flutter stable and Dart compatible with the SDK range in `pubspec.yaml`.
- Node.js version supported by `backend/package.json` and `web-app/package.json`.
- A Supabase project with the required schema, migrations, authentication and Storage configuration.
- Provider credentials only for the integrations you intend to run (for example, Firebase, payment, email/SMS or AI providers).

### Native app

From the repository root:

```bash
flutter pub get
cp .env.example .env
# Set the public Supabase URL and anon key, plus the backend URL.
flutter run
```

Do not commit populated `.env` files, signing keys, service-role keys or provider secrets. Android release signing requires the developer-owned keystore and `android/key.properties`; see `android/key.properties.example` and the Android release workflow.

### Public web app

```bash
cd web-app
cp config.example.js config.js
# Set SUPABASE_URL and SUPABASE_ANON_KEY in config.js for local testing.
npm test
npm run serve
```

Open http://localhost:4173. The browser client must use only the public Supabase anon key and public service URLs. Never expose a Supabase service-role key, database password, payment secret, JWT signing secret or other server credential in browser code.

For Vercel, configure the public Supabase and backend URL environment variables in the project settings. The build script generates the browser configuration. Review `web-app/README.md` before changing deployment behavior.

### Backend

```bash
cd backend
cp .env.example .env
# Fill only the secrets for integrations you have configured.
npm install
npm run dev
```

See [backend/README.md](backend/README.md) for endpoints, configuration and deployment notes. Keep backend secrets on the server.

### Admin console

See [admin-web/README.md](admin-web/README.md). Admin access must use individual authorised accounts and role-based permissions. Never embed admin credentials in the public web or native application.

## Configuration and security

- Use `.env.example` and `backend/.env.example` as templates; local secret files are ignored by Git.
- Use Supabase Row Level Security as the database access boundary. Review policies for every table before production.
- Keep public anon keys separate from service-role and provider secrets.
- Use private storage buckets and time-limited signed URLs for private media.
- Rotate any credential that has ever been committed or exposed.
- Review [security/policies/data-handling.md](security/policies/data-handling.md) and the security documentation under `docs/`.
- Do not use production personal data in tests or screenshots.

## Tests and quality checks

Run the checks relevant to the surface you changed:

```bash
# Flutter static analysis and tests
flutter analyze
flutter test

# Public web JavaScript syntax check
cd web-app && npm test

# Backend checks
cd backend && npm test
```

Some commands may require dependencies, secrets, a running Supabase project, Redis, provider credentials or device/emulator access. A successful syntax check is not equivalent to end-to-end verification. Record external dependencies and failed checks in [BLOCKERS.md](BLOCKERS.md); never report an unrun test as passing.

## User acquisition and community growth

FUSKAMO's growth workflow should identify relevant football communities and public conversations, then support human-reviewed, context-specific participation. See [growth/README.md](growth/README.md) for the Instagram and Reddit discovery plan, official API boundaries, keyword monitoring, consent and outreach rules.

FUSKAMO does not scrape private accounts, harvest personal contact details, automate unsolicited bulk DMs, evade platform limits or post repetitive promotional spam.

## Legal

- [Privacy Policy](legal/privacy-policy.md)
- [Terms of Service](legal/terms.md)
- [Third-party licences](legal/licences.md)

These documents are launch drafts and must be reviewed against the real operating entity, data flows, jurisdictions and safeguarding practices before public release.

## Contributing

Keep changes scoped to the relevant product surface. Preserve migrations, signing configuration, CI, environment templates and deployment assets. Add or update tests and documentation with every behavior change. Never commit secrets, user data, generated build output or local machine state.

## License

See [LICENSE](LICENSE).
