const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');

/** Powers the admin Overview dashboard (admin-web/index.html) — a handful
 * of counts pulled with the service-role client so they're not limited by
 * any RLS policy (an admin needs to see pending/rejected rows too, not
 * just what's public). */
class AdminStatsRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase is not configured on this server yet', 503);
    return client;
  }

  async _count(table, filters = {}) {
    let query = this._client().from(table).select('id', { count: 'exact', head: true });
    for (const [key, value] of Object.entries(filters)) query = query.eq(key, value);
    const { count, error } = await query;
    if (error) throw new AppError(error.message, 400);
    return count || 0;
  }

  async getStats() {
    const [
      approvedPlayers,
      pendingPlayers,
      rejectedPlayers,
      verifiedScouts,
      pendingScouts,
    ] = await Promise.all([
      this._count('players', { status: 'approved' }),
      this._count('players', { status: 'pending' }),
      this._count('players', { status: 'rejected' }),
      this._count('scouts', { verified: true }),
      this._count('scouts', { verified: false }),
    ]);

    return {
      approvedPlayers,
      pendingPlayers,
      rejectedPlayers,
      verifiedScouts,
      pendingScouts,
      // admin-web/index.html's Overview cards read these two combined
      // totals directly — they previously didn't exist on this object at
      // all, so those two stat cards silently always showed '—'.
      totalPlayers: approvedPlayers + pendingPlayers + rejectedPlayers,
      totalScouts: verifiedScouts + pendingScouts,
    };
  }

  /** Backs the admin Audit Log dashboard (admin-web/index.html). */
  async listRecentAuditLogs(limit = 50) {
    const { data, error } = await this._client()
      .from('audit_logs')
      .select()
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new AppError(error.message, 400);
    return data;
  }
}

module.exports = new AdminStatsRepository();
