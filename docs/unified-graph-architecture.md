# FUSKAMO Unified Graph Architecture

FUSKAMO is organized as a one-way trust-aware graph:

Identity (`@username`)
-> Social graph (follow, block, mute, group membership, messaging)
-> Content graph (posts, groups, reels, stories, player/scout/club objects)
-> Recommendation (candidate generation -> safety gate -> ranking -> diversity)
-> Scoreboard (meaningful outcomes + trust + quality + momentum)
-> Trust/Safety (verification evidence, reports, fraud, enforcement)

## Anti-feedback-loop rules

1. A verification tick never creates trust by itself.
2. A recommendation impression never increases trust or scoreboard score.
3. A paid boost never grants verification and is not a trust signal.
4. Likes/follows are logarithmically capped and require a confirmed account.
5. Reports are evidence, not automatic guilt; enforcement requires thresholds/review.
6. Blocks and severe safety risk can suppress recommendation candidates.
7. Recommendation ranking is diversified by author and content type.
8. Meaningful downstream outcomes (save/share/contact/complete/join) matter more than raw impressions.

## Ranking pipeline

Candidate generation -> block/privacy filtering -> safety gate -> relationship/role affinity -> quality/trust -> meaningful engagement -> freshness -> exploration -> author/type diversity -> impression logging.

The backend exposes `/api/recommendations/feed` and `/api/recommendations/events` with model version `unified-v1`.

## What the scoreboard must not learn from

The scoreboard must not reward:

- raw recommendation impressions;
- paid boosts;
- verification status by itself;
- repeated self-interactions;
- activity from blocked accounts;
- suspicious engagement clusters.

It can reward verified identity only through the trust component, while the role-specific quality component measures the actual football/product value of the account.
