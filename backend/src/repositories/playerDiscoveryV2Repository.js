'use strict';

const { getPool } = require('../database/pool');
const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

const CANDIDATE_POOL_LIMIT = 1500;

async function getScoutForUser(userId) {
  const client = getSupabaseAdmin();
  if (!client) throw new AppError('Backend is not configured (Supabase admin client unavailable)', 503);
  const { data, error } = await client.from('scouts')
    .select('id, preferred_positions, preferred_countries, age_min, age_max, preferred_foot, preferred_height_min')
    .eq('user_id', userId).eq('verified', true).maybeSingle();
  if (error) { logger.error('V2 getScoutForUser failed', error); throw new AppError('Could not load scout profile', 500); }
  return data;
}

async function getCandidatePlayers(subjectId) {
  const pool = getPool();
  if (!pool) throw new AppError('Backend is not configured (Postgres pool unavailable)', 503);
  const { rows } = await pool.query(`
    with engagement as (
      select player_id,
        count(*) filter (where event_type = 'view') as views_7d,
        count(*) filter (where event_type = 'save') as saves_7d,
        count(*) filter (where event_type = 'contact') as contacts_7d,
        count(*) filter (where event_type = 'share') as shares_7d,
        count(*) filter (where event_type = 'skip') as skips_7d,
        count(*) filter (where event_type in ('hide','report')) as negative_7d,
        count(distinct ip_hash) as distinct_ips,
        count(distinct device_hash) as distinct_devices,
        count(distinct actor_id) as distinct_actors,
        count(*) as total_events
      from player_events where created_at > now() - interval '7 days' group by player_id
    ),
    recent as (
      select distinct player_id from player_events
      where actor_id = $1 and created_at > now() - interval '30 days'
    )
    select p.id, p.name, p.position, p.age, p.country, p.league, p.club, p.height, p.foot,
      p.status, p.video_url, p.jersey_number, p.created_at, p.featured_until,
      p.profile_completeness, p.quality_score, p.fraud_score,
      coalesce(pr.verified, false) as profile_verified, coalesce(pr.badge_type, 'none') as badge_type,
      coalesce(pr.trust_score, 0)::numeric as trust_score,
      coalesce(pa.achievement_count, 0)::int as achievement_count,
      coalesce(e.views_7d, 0)::int as views_7d, coalesce(e.saves_7d, 0)::int as saves_7d,
      coalesce(e.contacts_7d, 0)::int as contacts_7d, coalesce(e.shares_7d, 0)::int as shares_7d,
      coalesce(e.skips_7d, 0)::int as skips_7d, coalesce(e.negative_7d, 0)::int as negative_7d,
      coalesce(e.distinct_ips, 0)::int as distinct_ips, coalesce(e.distinct_devices, 0)::int as distinct_devices,
      coalesce(e.distinct_actors, 0)::int as distinct_actors, coalesce(e.total_events, 0)::int as total_events,
      exists(select 1 from recent r where r.player_id = p.id) as seen_recently
    from players p
    left join engagement e on e.player_id = p.id
    left join profiles pr on pr.user_id = p.submitted_by
    left join (select user_id, count(*) as achievement_count from profile_achievements group by user_id) pa on pa.user_id = p.submitted_by
    where p.status = 'approved'
    order by p.created_at desc limit $2`, [subjectId, CANDIDATE_POOL_LIMIT]);
  return rows;
}

async function getRecentPlayerIds(subjectId, limit = 50) {
  const pool = getPool();
  if (!pool) return [];
  const { rows } = await pool.query(`select player_id from player_events where actor_id = $1 order by created_at desc limit $2`, [subjectId, limit]);
  return rows.map((r) => String(r.player_id));
}

async function logEvent({ playerId, actorId, eventType, ipHash, deviceHash, metadata = {} }) {
  const client = getSupabaseAdmin();
  if (!client) throw new AppError('Backend is not configured (Supabase admin client unavailable)', 503);
  const { error } = await client.from('player_events').insert({ player_id: playerId, actor_id: actorId || null, event_type: eventType, ip_hash: ipHash || null, device_hash: deviceHash || null, metadata });
  if (error) { logger.error('V2 logEvent failed', error); throw new AppError('Could not record engagement event', 500); }
}

async function recomputeFraudSignals() {
  const pool = getPool();
  if (!pool) return { updated: 0 };
  const { rows } = await pool.query(`select player_id, count(*) total_events, count(distinct ip_hash) distinct_ips, count(distinct device_hash) distinct_devices, count(distinct actor_id) distinct_actors from player_events where created_at > now() - interval '7 days' group by player_id`);
  let updated = 0;
  for (const row of rows) {
    const ip = 1 - Math.min(Number(row.distinct_ips), Number(row.total_events)) / Number(row.total_events || 1);
    const device = 1 - Math.min(Number(row.distinct_devices), Number(row.total_events)) / Number(row.total_events || 1);
    const actor = 1 - Math.min(Number(row.distinct_actors), Number(row.total_events)) / Number(row.total_events || 1);
    const fraud = Math.max(0, Math.min(1, ip * 0.4 + device * 0.4 + actor * 0.2));
    await pool.query('update players set fraud_score = $1 where id = $2', [Math.round(fraud * 100) / 100, row.player_id]);
    updated += 1;
  }
  return { updated };
}

async function recordImpressions({ subjectId, rows, experimentKey = null, variant = null }) {
  const pool = getPool();
  if (!pool || !rows?.length) return { recorded: 0 };
  const values = [];
  const params = [];
  rows.forEach((row, index) => {
    const offset = index * 8;
    values.push(`($${offset + 1}, 'player_discovery_v2', $${offset + 2}, $${offset + 3}, $${offset + 4}, $${offset + 5}, $${offset + 6}, $${offset + 7})`);
    params.push(subjectId, row.player.id, row.position, row.model, row.modelVersion, experimentKey, variant);
  });
  await pool.query(`insert into ranking_impressions(subject_id, surface, item_id, position, model_name, model_version, experiment_key, variant) values ${values.join(',')}`, params);
  return { recorded: rows.length };
}

module.exports = { getScoutForUser, getCandidatePlayers, getRecentPlayerIds, logEvent, recomputeFraudSignals, recordImpressions, CANDIDATE_POOL_LIMIT };
