const { createClient } = require('@supabase/supabase-js');
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
  client = createClient(env.supabase.url, env.supabase.serviceRoleKey);
  return client;
}

module.exports = { getSupabaseAdmin };
