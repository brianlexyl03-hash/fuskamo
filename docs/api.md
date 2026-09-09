# API

Custom backend REST API — see `backend/README.md` for the "why" and `api/openapi.yaml` for the full machine-readable spec. Base path: `/api`.

## Auth
Most endpoints require an `x-api-key` header matching `BACKEND_API_KEY` from `backend/.env`. The M-Pesa callback is the one exception (Safaricom calls it directly and won't send your key).

## Endpoints
| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness check |
| POST | `/mpesa/stk-push` | Trigger an M-Pesa payment prompt |
| POST | `/mpesa/callback` | Safaricom's async payment result (webhook) |
| POST | `/ai/summarize-player` | AI-generated scouting note for a submission |
| GET | `/players-admin/pending` | List submissions awaiting review |
| POST | `/players-admin/:id/approve` | Approve a submission (privileged — service role key) |
| POST | `/players-admin/:id/reject` | Reject a submission |
| GET | `/external/countries` | Live country list for the submit form |

## Flutter side
`lib/services/backend_api_service.dart` wraps the M-Pesa and AI endpoints for the app. Direct Supabase reads (feed, scouts) still go straight from the app to Supabase with the anon key, unchanged from the original architecture — only privileged/secret-needing operations route through this backend.
