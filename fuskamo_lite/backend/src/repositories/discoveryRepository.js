'use strict';

const { getPool } = require('../database/pool');
const { getSupabaseAdmin } = require('../config/supabase');
const { computeFraudScore } = require('../services/discoveryEngine');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

// Hard cap on how many approved players get pulled into the scoring pass.
// This app's whole `players` table is nowhere near this size today, but the
// cap (most-recent-first) is what stands in for a real candidate-generation
// stage if the catalog grows — score the newest N rather than table-scan
// and score every approved player on every request.
const CANDIDATE_POOL_LIMIT = 1000;

/**
 * Looks up the verified scout profile linked to a signed-in user (via
 * scouts.user_id, added in 011_ownership_and_scout_applications.sql).
 * Returns null if the account has no scout profile yet, or it's still
 * pending verification — either way, no discovery feed for them.
 */
async function getScoutForUser(userId) {
  const client = getSupabaseAdmin();
  if (!client) throw new AppError('Backend is not configured (Supabase admin client unavailable)', 503);

  const { data, error } = await client
    .from('scouts')
    .select(
      'id, preferred_positions, preferred_countries, age_min, age_max, preferred_foot, preferred_height_min'
    )
    .eq('user_id', userId)
    .eq('verified', true)
    .maybeSingle();

  if (error) {
    logger.error('getScoutForUser failed', error);
    throw new AppError('Could not load scout profile', 500);
  }
  return data;
}

/**
 * Fetches approved players plus their 7-day view/save/contact/share counts
 * in a single query — this needs the raw pg pool (not supabase-js/PostgREST)
 * because it's a real aggregation with a date-windowed CTE, not a
 * single-table read.
 */
async function getEligiblePlayers() {
  const pool = getPool();
  if (!pool) throw new AppError('Backend is not configured (Postgres pool unavailable)', 503);

  const { rows } = await pool.query(
    `
    with engagement as (
      select
        player_id,
        count(*) filter (where event_type = 'view')    as views_7d,
        count(*) filter (where event_type = 'save')     as saves_7d,
        count(*) filter (where event_type = 'contact')  as contacts_7d,
        count(*) filter (where event_type = 'share')    as shares_7d
      from player_events
      where created_at > now() - interval '7 days'
      group by player_id
    )
    select
      p.id, p.name, p.position, p.age, p.country, p.league, p.club, p.height, p.foot,
      p.status, p.video_url, p.jersey_number, p.created_at, p.featured_until,
      p.profile_completeness, p.quality_score, p.fraud_score,
      coalesce(pr.verified, false) as profile_verified, coalesce(pr.badge_type, 'none') as badge_type,
      coalesce(pr.trust_score, 0)::numeric as trust_score,
      coalesce(pa.achievement_count, 0)::int as achievement_count,
      coalesce(e.views_7d, 0)::int    as views_7d,
      coalesce(e.saves_7d, 0)::int    as saves_7d,
      coalesce(e.contacts_7d, 0)::int as contacts_7d,
      coalesce(e.shares_7d, 0)::int   as shares_7d
    from players p
    left join engagement e on e.player_id = p.id
    left join profiles pr on pr.user_id = p.submitted_by
    left join (select user_id, count(*) as achievement_count from profile_achievements group by user_id) pa on pa.user_id = p.submitted_by
    where p.status = 'approved'
    order by p.created_at desc
    limit $1
    `,
    [CANDIDATE_POOL_LIMIT]
  );
  return rows;
}

/**
 * Records one engagement event. Always called from discoveryController.js
 * with a server-computed ip_hash/device_hash — never trust these from the
 * client directly, or fraud scoring becomes trivially spoofable by whoever
 * is doing the fraud.
 */
async function logEvent({ playerId, actorId, eventType, ipHash, deviceHash }) {
  const client = getSupabaseAdmin();
  if (!client) throw new AppError('Backend is not configured (Supabase admin client unavailable)', 503);

  const { error } = await client.from('player_events').insert({
    player_id: playerId,
    actor_id: actorId || null,
    event_type: eventType,
    ip_hash: ipHash || null,
    device_hash: deviceHash || null,
  });
  if (error) {
    logger.error('logEvent failed', error);
    throw new AppError('Could not record engagement event', 500);
  }
}

/**
 * Nightly job body (wired into scheduledJobs.js): recomputes
 * players.fraud_score for every player with 7-day event activity, from
 * IP/device concentration in player_events. Players with no recent events
 * are left alone rather than reset to 0 — silence isn't evidence of
 * innocence, but it's not evidence of fraud either.
 */
async function recomputeFraudScores() {
  const pool = getPool();
  if (!pool) {
    logger.warn('recomputeFraudScores skipped — Postgres pool unavailable');
    return { updated: 0 };
  }

  const { rows } = await pool.query(`
    select
      player_id,
      count(*)                          as total_events,
      count(distinct ip_hash)           as distinct_ips,
      count(distinct device_hash)       as distinct_devices
    from player_events
    where created_at > now() - interval '7 days'
    group by player_id
  `);

  let updated = 0;
  for (const row of rows) {
    const fraudScore = computeFraudScore({
      totalEvents: Number(row.total_events),
      distinctIps: Number(row.distinct_ips),
      distinctDevices: Number(row.distinct_devices),
    });
    await pool.query('update players set fraud_score = $1 where id = $2', [fraudScore, row.player_id]);
    updated += 1;
  }
  return { updated };
}

module.exports = {
  getScoutForUser,
  getEligiblePlayers,
  logEvent,
  recomputeFraudScores,
  CANDIDATE_POOL_LIMIT,
};
