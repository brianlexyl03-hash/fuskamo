const { getSupabaseAdmin } = require('../config/supabase');
const asyncHandler = require('../utils/asyncHandler');

const MAX_QUERY_LENGTH = 100;
const MAX_RESULTS = 40;

// Search is delegated to the shared, database-side search contract used by
// the native client. The matching expressions are backed by pg_trgm indexes
// added in migration 032; the API does not construct unindexed ILIKE scans.
exports.search = asyncHandler(async (req, res) => {
  const query = String(req.query.q || '').trim().slice(0, MAX_QUERY_LENGTH);
  if (!query) return res.status(200).json({ success: true, results: [] });

  const client = getSupabaseAdmin();
  if (!client) {
    return res.status(503).json({
      success: false,
      error: { code: 'SEARCH_UNAVAILABLE', message: 'Search is temporarily unavailable.' },
    });
  }

  const { data, error } = await client.rpc('search_fuskamo_v2', {
    p_query: query,
    p_limit: MAX_RESULTS,
  });

  if (error) throw error;

  const results = (data || []).map((row) => ({
    type: row.kind,
    id: row.id,
    name: row.title,
    meta: row.subtitle,
    username: row.username,
    avatarUrl: row.avatar_url,
    verified: Boolean(row.verified),
    badgeType: row.badge_type,
    score: Number(row.score || 0),
  }));

  return res.status(200).json({ success: true, results });
});
