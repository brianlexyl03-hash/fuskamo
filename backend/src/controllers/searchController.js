const { getSupabaseAdmin } = require('../config/supabase');
const asyncHandler = require('../utils/asyncHandler');

// Public, unauthenticated universal search across the surfaces the web/Flutter
// clients show in one search box. Read-only, and only returns rows already
// public per each table's own RLS-equivalent rule (approved players,
// verified scouts, public groups) since this uses the admin client but we
// filter to publicly-safe rows explicitly rather than relying on RLS.
exports.search = asyncHandler(async (req, res) => {
  const q = (req.query.q || '').toString().trim().slice(0, 100);
  if (!q) return res.status(200).json({ success: true, results: [] });

  const client = getSupabaseAdmin();
  if (!client) return res.status(200).json({ success: true, results: [] });

  const like = `%${q}%`;

  const [players, scouts, groups] = await Promise.all([
    client.from('players').select('id,name,position,country').eq('status', 'approved').ilike('name', like).limit(8),
    client.from('scouts').select('id,name,organization').eq('verified', true).ilike('name', like).limit(8),
    client.from('groups').select('id,name,slug,description').eq('privacy', 'public').ilike('name', like).limit(8),
  ]);

  const results = [
    ...(players.data || []).map((p) => ({ type: 'Player', id: p.id, name: p.name, meta: p.position })),
    ...(scouts.data || []).map((s) => ({ type: 'Scout', id: s.id, name: s.name, meta: s.organization })),
    ...(groups.data || []).map((g) => ({ type: 'Group', id: g.id, name: g.name, meta: g.description })),
  ];

  res.status(200).json({ success: true, results });
});
