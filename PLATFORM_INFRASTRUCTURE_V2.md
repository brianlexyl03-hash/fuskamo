# FUSKAMO Platform Infrastructure V2

## Built in this revision

1. Event contract + local event bus
2. Feature-store contract with bounded TTL/eviction
3. Multi-signal recommendation/ranking engine
4. Safety gate, negative feedback and author diversity
5. Search scoring/index document contract
6. Deterministic A/B experiment assignment
7. Notification ranking/diversity
8. Abuse-risk scoring and content safety signals
9. Media validation/pipeline contract
10. Video HLS manifest plan, intentionally gated as Coming Soon
11. Analytics event buffer
12. Model registry/version contract
13. Realtime event-stream abstraction
14. Idempotency-key contract
15. Outbox/retry persistence schema
16. Security-event schema
17. Service health/SLO schema + local tracker
18. Ranking impression and search-query telemetry schema
19. Device/account risk linkage schema
20. API usage-window schema
21. Disaster-recovery checkpoint schema
22. Creator metric snapshot schema
23. Platform-intelligence API routes
24. Migrations 028 and 029

## Intentionally not faked

The following are adapter/infrastructure dependencies and therefore cannot be honestly marked live until provisioned:

- Supabase/Postgres execution
- Redis/BullMQ distributed queues
- object storage and CDN
- production WebSocket gateway
- ML training/inference infrastructure
- push providers
- observability backend
- multi-region deployment
- real video transcoding/HLS workers

The application contains contracts and local implementations for these areas so they can be wired to real infrastructure without replacing the core business logic.

## Client architecture

- Flutter full client
- Flutter Lite client
- User-facing web client
- Admin web console

All share the same account/backend/database architecture; admin privileges remain isolated.
