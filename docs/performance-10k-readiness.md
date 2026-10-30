# FUSKAMO performance and 10,000-user readiness plan

## Do not confuse registered users with concurrency

"10,000 users" can mean 10,000 accounts, 10,000 daily active users, or 10,000 simultaneous sessions. Those are different capacity targets. This checklist treats 10,000 simultaneous sessions as a stretch target that must be demonstrated with a staged load test, not assumed from a successful build.

## Capacity model

Before choosing infrastructure, capture a baseline for:
- Peak concurrent active sessions and requests/second per active user.
- Feed reads, discovery queries, profile reads, likes/comments, messages, notification events and media uploads per minute.
- p50/p95/p99 API latency, HTTP 4xx/5xx/timeouts, CPU/memory, event-loop delay and database connection saturation.
- Database query plans, rows scanned, lock waits, index hit rates, connection-pool utilization, and Supabase Realtime connections/fan-out.
- Media bandwidth, image transformation costs, cache hit rate, upload limits and storage egress.

Use this starting estimate: peak RPS = concurrent active users × measured requests per active user per second. Do not use a guessed requests-per-user number as a production capacity claim.

## Required architecture checks

- Keep pagination cursor-based for feeds, messages and discovery; never fetch an unbounded timeline or all conversations.
- Confirm composite indexes match actual filters and ordering from production queries; inspect EXPLAIN (ANALYZE, BUFFERS) on representative seeded data.
- Verify row-level security policies and query plans under realistic user isolation; avoid broad service-role reads in request paths.
- Use bounded timeouts, request-size limits, validation and rate limits on authentication, posting, search, uploads and messaging.
- Move slow/large work (media processing, emails, notification fan-out, analytics aggregation) to a queue/worker with retries, idempotency and dead-letter visibility.
- Use object storage/CDN for media, responsive image variants, lazy loading, and avoid loading videos before they're near the viewport.
- Cache only safe public or user-scoped data with correct invalidation; never share private feed/message data across users.
- Bound Supabase/Postgres connections with pooling; monitor realtime fan-out and separate worker capacity from API capacity when appropriate.
- Add graceful degradation for recommendation ranking, optional analytics and push delivery so an optional subsystem failure doesn't take down core browsing or messaging.

## Staged load test

1. Record baseline on a production-like staging environment with synthetic users and realistic RLS/data volume.
2. Ramp through 100, 500, 1,000, 2,500, 5,000 and 10,000 concurrent sessions; hold each stage long enough to expose connection leaks and memory growth.
3. Mix read/write flows: feed pagination, search/discovery, profile views, follow, likes/comments, message send/read, notification fetch and media metadata. Use controlled test accounts only.
4. Add bursts and failure injection: cold cache, slow database, worker restart, throttled storage, invalid input and provider timeouts.
5. Define pass criteria before the run. Suggested starting SLOs: API p95 under 500 ms for ordinary reads and under 800 ms for writes, server error rate below 1%, no unbounded memory/queue growth, and no cross-user data leakage. Adjust only with explicit product requirements and observed baseline.
6. Repeat after fixing bottlenecks; preserve raw metrics, workload definitions, environment sizing, dataset size, and a reproducible report in CI or release artifacts.

## UI performance and motion

- Target a stable 60 fps on supported devices (16.7 ms frame budget) and test 120 Hz displays where supported (8.3 ms frame budget).
- Animate transform/opacity where possible; avoid animating layout, large blur regions, or full-screen backdrop filters during scrolling.
- Apply blur only to small floating navigation/overlays; provide a solid/translucent fallback and honor reduced-motion preferences.
- Lazy-load images/video, reserve aspect ratio to prevent layout shift, use thumbnails, and paginate feed items.
- Measure Flutter frame raster/build times and browser long tasks on low-end Android devices, not just flagship phones.

## Release gate

Do not claim "supports 10,000 concurrent users" until:
- All critical user flows pass automated and authenticated smoke tests.
- Flutter analyze/build and web syntax/lint checks pass.
- A reproducible staging test sustains 10,000 concurrent sessions within agreed SLOs.
- Database, API, worker, realtime and media dashboards show no saturation or data-integrity issues.
- Security checks verify tenant isolation, RLS, rate limits and authorization under load.
