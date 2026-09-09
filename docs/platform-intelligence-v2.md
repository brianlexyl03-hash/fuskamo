# FUSKAMO Platform Intelligence v2

This layer implements the buildable core of the platform systems identified in the infrastructure audit without pretending to provide production infrastructure that has not been provisioned.

## Included
- Event contract and in-process event bus
- Feature-store contract with bounded TTL cache
- Multi-signal feed ranking with safety, freshness, affinity, negative feedback and author diversity
- Deterministic search scoring contract
- Sticky A/B experiment assignment
- Abuse-risk scoring and content safety signals
- Media upload pipeline contract and video manifest plan (video remains gated/Coming Soon)
- Notification ranking
- Analytics event buffering
- Model registry contract
- Realtime event stream abstraction
- Search document contract
- Platform-intelligence API routes
- Database migration 028 for events, features, search, experiments, analytics, abuse, media, notifications, presence and creator snapshots

## Production adapters still require credentials/infrastructure
- Supabase/Postgres execution
- Redis/BullMQ for distributed queues
- object storage/CDN
- real WebSocket infrastructure
- ML training/inference provider
- observability backend
- device push providers

The code intentionally keeps these adapters separate so local tests do not masquerade as production-scale tests.
