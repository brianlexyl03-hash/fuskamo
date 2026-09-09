# Unified Graph Contract

## Objects

`profile`, `post`, `reel`, `story`, `group`, `message`, `player`, `scout`, `club`

## Positive events

`open`, `view`, `watch`, `complete`, `like`, `comment`, `reply`, `save`, `share`, `repost`, `follow`, `join`, `message`, `contact`

## Negative events

`skip`, `not_interested`, `mute`, `block`, `report`

Negative feedback suppresses future recommendations more strongly than a positive impression boosts them.

## Separation of responsibilities

- Identity establishes who an account is.
- Social graph establishes relationships.
- Content graph establishes what exists and how people interact with it.
- Recommendation decides what to show next.
- Scoreboard measures meaningful reputation and momentum.
- Trust/safety gates and moderates the whole system.

No downstream ranking result is allowed to manufacture identity verification.
