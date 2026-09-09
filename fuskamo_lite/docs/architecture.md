# Architecture

FUSKAMO is a native Flutter application (Android + iOS from one Dart codebase) backed by a custom Node/Express backend for anything needing secrets or privileged access, with plain reads/writes still going straight to Supabase.

```
Flutter App
   │
   ├── screens/, widgets/, providers/, theme/  ← the UI, unchanged in shape
   ├── services/player_service.dart, scout_service.dart
   │       │
   │       ▼
   │   Supabase (direct, anon key, RLS-constrained)
   │       — plain reads (approved players, verified scouts)
   │       — plain inserts (new submission, forced to 'pending')
   │
   └── services/backend_api_service.dart
           │
           ▼
       Custom Backend  (/backend)
           │
           ├── M-Pesa           (Safaricom Daraja — STK Push + callback)
           ├── AI services       (player-summary generation)
           ├── External APIs      (e.g. live country list)
           └── Business logic     (approve/reject — privileged Supabase writes)
           │
           ▼
       Supabase (service role key — bypasses RLS)
```

## Why two paths to Supabase
Row Level Security lets the app talk to Supabase directly and safely for anything RLS can fully express — "anyone may insert a pending player," "anyone may read approved players." The moment an operation needs a secret (M-Pesa consumer secret, AI API key) or needs to bypass RLS entirely (approving a submission), it can't happen in the app — it has to happen server-side, which is what `/backend` is for. See `backend/README.md` for the full reasoning and endpoint list.

## Why not a WebView
The previous prototype was HTML/CSS/JS. That code was used only as a functional reference — every screen, form, and interaction has been rebuilt as real Flutter widgets and Dart logic. Nothing in the shipped app renders a webpage.
