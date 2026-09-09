'use strict';
const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

async function rpc(name, params = {}) {
  const client = getSupabaseAdmin();
  if (!client) throw new AppError('Backend is not configured', 503);
  const { data, error } = await client.rpc(name, params);
  if (error) {
    logger.error(`Unified graph RPC ${name} failed`, error);
    throw new AppError(`Unified graph operation failed: ${name}`, 500);
  }
  return data || [];
}

async function getCandidates(limit = 200) { return rpc('get_unified_candidate_signals', { p_limit: Math.min(Math.max(limit, 1), 500) }); }

async function getFollowing(userId) {
  const client = getSupabaseAdmin();
  const { data, error } = await client.from('profile_follows').select('followed_id').eq('follower_id', userId);
  if (error) throw new AppError('Could not load social graph', 500);
  return new Set((data || []).map((r) => r.followed_id));
}

async function getNegativeSignals(userId) {
  const client = getSupabaseAdmin();
  const { data, error } = await client.from('graph_events')
    .select('subject_user_id,event_type')
    .eq('actor_id', userId)
    .in('event_type', ['not_interested', 'mute', 'block', 'report'])
    .gte('created_at', new Date(Date.now() - 30 * 86400000).toISOString());
  if (error) throw new AppError('Could not load safety feedback', 500);
  const negative = new Map();
  const reports = new Map();
  for (const row of data || []) {
    if (!row.subject_user_id) continue;
    if (row.event_type === 'report') reports.set(row.subject_user_id, (reports.get(row.subject_user_id) || 0) + 1);
    else negative.set(row.subject_user_id, (negative.get(row.subject_user_id) || 0) + 1);
  }
  return { negative, reports };
}

async function recordImpressions(userId, entries) {
  const client = getSupabaseAdmin();
  if (!entries.length) return;
  const rows = entries.map((entry, index) => ({
    user_id: userId,
    object_type: entry.candidate.object_type,
    object_id: entry.candidate.object_id,
    position: index + 1,
    score: entry.score,
    model_version: 'unified-v2',
  }));
  const { error } = await client.from('recommendation_impressions').insert(rows);
  if (error) logger.warn('Could not persist recommendation impressions', error);
}

async function recordEvent({ userId, objectType, objectId, eventType, subjectUserId, sessionId, metadata }) {
  return rpc('record_graph_event', {
    p_object_type: objectType,
    p_object_id: objectId,
    p_event_type: eventType,
    p_subject_user_id: subjectUserId || null,
    p_value: 1,
    p_session_id: sessionId || null,
    p_metadata: metadata || {},
  });
}

module.exports = { getCandidates, getFollowing, getNegativeSignals, recordImpressions, recordEvent };
