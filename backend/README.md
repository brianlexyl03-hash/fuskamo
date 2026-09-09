# Backend

Custom Node/Express backend sitting between the Flutter app and Supabase, per this architecture:

```
Flutter App
   │
   ▼
Custom Backend  (this folder)
   │
   ├── M-Pesa           (Safaricom Daraja API — STK Push + callback)
   ├── AI services       (player-summary generation, OpenAI-compatible)
   ├── External APIs      (e.g. live country list)
   └── Business logic     (privileged Supabase writes: approve/reject players)
   │
   ▼
Supabase  (service-role key — bypasses Row Level Security)
```

## Why this exists (vs. the earlier "no backend needed" MVP)
The original MVP had the Flutter app talk to Supabase directly with the public anon key, which is safe *only* for operations Row Level Security can fully constrain (e.g. "anyone can insert a pending player"). Three things can't work that way:
- **M-Pesa** needs a consumer secret that must never ship inside an app binary.
- **AI provider calls** need an API key you want to meter/control, not hand out to every install.
- **Approving/rejecting a player** needs to bypass RLS entirely (the anon key structurally cannot do this) — that requires the Supabase *service role* key, which must stay server-side.

## Run locally
```bash
cd backend
cp .env.example .env   # then fill in real values
npm install
npm run dev
```

## Run via Docker
```bash
docker compose up --build
```

## Endpoints
- `GET /api/health` — liveness check
- `POST /api/mpesa/stk-push` — initiate an M-Pesa payment prompt (requires `x-api-key` header)
- `POST /api/mpesa/callback` — Safaricom's async payment result webhook (no API key — see `routes/mpesa.routes.js`)
- `POST /api/ai/summarize-player` — generates a short AI scouting note (requires `x-api-key`)
- `GET /api/players-admin/pending` / `POST /api/players-admin/:id/approve` / `.../reject` — privileged moderation (requires `x-api-key`; tighten with real admin roles in Phase 2)
- `GET /api/external/countries` — live country list for the submit form

Full request/response shapes: `../api/openapi.yaml` and `../docs/api.md`.

## What's still not wired up, and why
`notifications/smsService.js` and `email/emailService.js` are real, working implementations (Africa's Talking and SMTP respectively, gated behind their own `_assertConfigured()` checks) — but nothing in the app currently calls either one. No event (approval, boost payment, etc.) is wired to trigger an SMS or email yet; in-app notifications (Supabase Realtime) cover that today. Wire a call to `smsService.send()` / `emailService.send()` into `playerAdminRepository.js` or `mpesaController.js` wherever you want that channel to fire. `sockets/` is empty because Supabase Realtime already covers live updates without running a socket server.
