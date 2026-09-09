const { Pool } = require('pg');
const env = require('../config/env');
const logger = require('../utils/logger');

/**
 * Raw Postgres pool for true multi-statement transactions — supabase-js
 * (PostgREST) is one-statement-per-call and can't wrap several writes in a
 * single atomic transaction. Use this only when you genuinely need that
 * (e.g. "approve player AND write audit log, both or neither"); plain reads
 * and single-row writes should keep using the supabase-js client.
 */
let pool = null;

function getPool() {
  if (pool) return pool;
  if (!env.isConfigured.db) {
    logger.warn('SUPABASE_DB_URL not set — raw Postgres pool unavailable, transaction helpers will throw.');
    return null;
  }
  pool = new Pool({
    connectionString: env.supabase.dbConnectionString,
    max: 10,
    idleTimeoutMillis: 30000,
    ssl: { rejectUnauthorized: false }, // Supabase requires SSL; sandboxed cert chain
  });
  return pool;
}

/** Runs `fn` inside a BEGIN/COMMIT block, ROLLBACK on any thrown error. */
async function withTransaction(fn) {
  const p = getPool();
  if (!p) throw new Error('Postgres pool not configured — set SUPABASE_DB_URL');
  const client = await p.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { getPool, withTransaction };
