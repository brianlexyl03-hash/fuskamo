# FUSKAMO community discovery and user acquisition

This workflow is designed to find relevant **public football conversations and communities** on Instagram and Reddit, then help a human operator participate in a useful, personalised and policy-compliant way.

It is not a bot for scraping profiles, collecting private contact details, following accounts at scale, or sending unsolicited bulk messages.

## 1. Target communities

Prioritise people and organisations who publicly discuss:
- football player development, grassroots football and youth academies;
- scouting, talent identification, coaching and club recruitment;
- football trials, showcases, tournaments and local leagues;
- player highlight videos, training clips and football portfolios;
- football communities in Kenya and other African markets, then expand by country and language.

Do not infer that a person is a minor from their content and do not build prospect lists of children. If a public post concerns a young player, engage through the parent, guardian, club or academy account and follow safeguarding rules.

## 2. Instagram discovery

Use Instagram's native search and discovery tools for manual research. For software-assisted discovery, use Meta's official developer products only within the exact permissions and use cases approved for the app.

Important constraints:
- Instagram's APIs do not grant unrestricted search of all users, private profiles, followers or arbitrary public content.
- Do not scrape Instagram pages, bypass login, rotate accounts/IPs, harvest emails/phone numbers or automate follows, likes, comments or DMs.
- Use account insights, mentions, comments, hashtags or other data only where the authorised API product and permissions explicitly allow it.
- Obtain Meta App Review and user consent where required. Respect deletion, revocation, rate limits and platform policies.

Suggested human search phrases:
- `grassroots football Kenya`
- `football academy Kenya`
- `Kenya football trials`
- `young football talent Africa`
- `football scouting Africa`
- `player development academy`
- `football highlight video`
- `women's football Kenya`

## 3. Reddit discovery

Use Reddit search and relevant public football subreddits to find conversations where FUSKAMO can add genuine value. For automation, register an official Reddit application, use OAuth and comply with Reddit's current API terms, rate limits, data-use restrictions and deletion requirements.

Do not scrape Reddit HTML, evade rate limits, collect private information, or send unsolicited automated private messages. Save a link, subreddit, post title, date and a short relevance note only when permitted. Do not republish user content without permission.

Suggested search phrases:
- `football scouting`
- `grassroots football`
- `football academy Africa`
- `player highlight video`
- `football trials Kenya`
- `how to get scouted football`
- `football talent identification`

## 4. Human-reviewed lead workflow

1. Search approved public surfaces for a relevant conversation.
2. Record the public URL, platform, date, topic and why FUSKAMO may be relevant.
3. Exclude minors as direct marketing prospects and exclude private or sensitive information.
4. Review the community rules and whether promotion is allowed.
5. Draft a reply that directly answers the user's question before mentioning FUSKAMO.
6. A human reviews and posts the reply from the authorised account.
7. Track only aggregate outcomes: replies, visits, voluntary sign-ups and opt-outs.
8. Honour deletion requests and do not re-contact people who object.

## 5. Outreach principles

- Be transparent that you represent FUSKAMO.
- Never pretend to be a player, scout or community member you are not.
- Do not promise trials, contracts, scholarships, recruitment or guaranteed exposure.
- Do not send repetitive comments or unsolicited bulk messages.
- Do not use purchased, scraped or inferred contact lists.
- Respect subreddit rules, Instagram policies and requests not to be contacted.

Example public reply:

> I saw your question about getting football clips in front of scouts. A useful first step is to keep a short, recent highlight video, add your position and playing context, and make sure a coach or academy can verify your details. FUSKAMO is building a football talent-discovery platform for player profiles and scouting discovery; if that is relevant, you can learn more at https://fuskamo.vercel.app. No platform can guarantee a trial or contract.

Use this only where community rules allow self-promotion, and tailor it to the actual discussion rather than pasting it repeatedly.

## 6. What is required before unattended automation

The repository does not currently contain verified Meta or Reddit API credentials, approved app permissions or an authorised account connection. Therefore unattended collection or posting is not enabled.

To build a compliant monitor:
- create and verify the Meta developer app and approved permissions for the exact Instagram use case;
- register the Reddit OAuth application and confirm current API access terms;
- add credentials to a secret manager, never source control;
- implement API-specific rate limiting, deletion propagation, audit logs and data minimisation;
- store public post references rather than profile dossiers;
- keep human approval before any public response or direct contact.

Until those prerequisites are complete, use the manual search workflow above. No platform login, credential, user list or outreach action is fabricated by this repository.
