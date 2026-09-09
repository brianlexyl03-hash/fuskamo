# FUSKAMO Platform Operations V1 — free-first build

This release completes the next free-build layer: moderation, notification routing, deep links, offline synchronization, account security, first-party analytics, and recommendation V2.

## 10. Moderation
- `moderation_cases` stores reports with target, reason, severity, assignment and resolution.
- `moderation_evidence` stores reviewer/user evidence.
- `moderation_appeals` gives users a formal appeal path.
- Existing moderation RPCs remain the platform-admin enforcement path.

## 11. Notifications
- `notification_events` is the canonical event bus.
- `notification_delivery_attempts` records channel delivery attempts.
- New events are mirrored to the existing `notifications` table so the current Flutter realtime provider receives social, group and message notifications without a paid socket service.
- Dedupe keys prevent repeated notification spam.

## 12. Deep links
Canonical paths are supported for profiles, players, clubs, scouts, coaches, posts, reels, stories, groups and invites. `deep_link_objects` materializes shareable objects and hides secret groups.

## 13. Offline
- Flutter maintains a durable local outbox.
- Backend accepts up to 100 operations per sync call.
- Operations are idempotent through `(user_id, client_operation_id)`.
- Supported free-first mutations include follow/unfollow, post like/unlike, comments, direct messages, group membership, poll votes, player saves, analytics and recommendation feedback.
- Conflicts are persisted for later review.

## 14. Security
- Device/session registry.
- Session revocation.
- Security settings for login alerts, new-device alerts and discoverability.
- Security event schema for future enforcement.
- Existing MFA and Supabase recovery remain the authentication source of truth.

## 15. Analytics
- First-party `analytics_events` with no paid analytics provider.
- Daily rollups can be refreshed with `refresh_analytics_rollup(date)`.
- Existing creator analytics remains available; this layer adds platform-wide event contracts.

## 16. Recommendation V2
The deterministic ranker remains explainable but now includes role affinity, creator/category affinity, quality, trust, safety, engagement, momentum, freshness, exploration and recent-author/type diversity penalties. Negative feedback and reports are weighted more heavily than positive clicks.

No impressions are converted directly into trust or verification. Paid boosts are outside the recommendation reputation calculation.

## Cost boundary
The code is buildable without purchasing infrastructure. Large-scale video storage/CDN, heavy transcoding, and high-volume push/email/SMS delivery remain infrastructure costs and are deliberately isolated behind existing adapters.
