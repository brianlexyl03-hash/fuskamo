const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');

/** Backs `notifications` (in-app) and `notification_preferences` tables —
 * see database/migrations/005_notifications.sql. In-app notifications are
 * just rows the Flutter app subscribes to live via Supabase Realtime
 * (no socket server needed — see backend/src/sockets/README.md). */
class NotificationRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase not configured', 503);
    return client;
  }

  async create({ userId, title, body, type }) {
    const { data, error } = await this._client()
      .from('notifications')
      .insert([{ user_id: userId, title, body, type, read: false }])
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async listForUser(userId) {
    const { data, error } = await this._client()
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async markRead(id) {
    const { data, error } = await this._client()
      .from('notifications')
      .update({ read: true })
      .eq('id', id)
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async getPreferences(userId) {
    const { data, error } = await this._client()
      .from('notification_preferences')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
    if (error) throw new AppError(error.message, 400);
    return data || { user_id: userId, sms_enabled: true, email_enabled: true, push_enabled: true };
  }

  async setPreferences(userId, prefs) {
    const { data, error } = await this._client()
      .from('notification_preferences')
      .upsert([{ user_id: userId, ...prefs }])
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }
}

module.exports = new NotificationRepository();
