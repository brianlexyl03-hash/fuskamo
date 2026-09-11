const { createClient } = require('@supabase/supabase-js');
const WebSocket = require('ws');
const env = require('./env');
const logger = require('../utils/logger');

let client = null;

/**
 * Server-side Supabase client using the SERVICE ROLE key — this bypasses
 * Row Level Security, which is exactly why it lives only here (never sent
 * to the Flutter app) and is used only for privileged operations like
 * approving a player submission.
 */
function getSupabaseAdmin() {
  if (client) return client;
  if (!env.isConfigured.supabase) {
    logger.warn('Supabase admin client requested but SUPABASE_URL/SERVICE_ROLE_KEY are not set.');
    return null;
  }
  // supabase-js always constructs an internal Realtime client, which on
  // Node < 22 needs an explicit WebSocket implementation passed in (Node
  // has no native WebSocket support until v22). This admin client never
  // subscribes to realtime channels, so we just satisfy the constructor.
  client = createClient(env.supabase.url, env.supabase.serviceRoleKey, {
    realtime: { transport: WebSocket },
  });
  return client;
}

module.exports = { getSupabaseAdmin };
