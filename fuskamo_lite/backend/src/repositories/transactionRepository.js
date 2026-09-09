const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');

/** Backs the `transactions` table (database/migrations/002_transactions.sql) —
 * the source of truth for every M-Pesa payment attempt, used for duplicate
 * protection, reconciliation, and transaction history. */
class TransactionRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase is not configured', 503);
    return client;
  }

  async createPending({ checkoutRequestId, merchantRequestId, phoneNumber, amount, accountReference }) {
    const { data, error } = await this._client()
      .from('transactions')
      .insert([{
        checkout_request_id: checkoutRequestId,
        merchant_request_id: merchantRequestId,
        phone_number: phoneNumber,
        amount,
        account_reference: accountReference,
        status: 'pending',
      }])
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async findByCheckoutId(checkoutRequestId) {
    const { data, error } = await this._client()
      .from('transactions')
      .select()
      .eq('checkout_request_id', checkoutRequestId)
      .maybeSingle();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Used by the refund flow (controllers/mpesaController.js) to resolve
   * our own UUID into the real Safaricom receipt number and original
   * amount — the refund endpoint takes our `id`, never a client-supplied
   * Safaricom TransactionID or amount directly, specifically so it can't
   * be pointed at an arbitrary/mismatched transaction. */
  async findById(id) {
    const { data, error } = await this._client().from('transactions').select().eq('id', id).maybeSingle();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Idempotent: if this checkoutRequestId was already finalized, does
   * nothing and returns the existing row — protects against Safaricom
   * retrying a callback delivery and double-crediting a payment. */
  async finalize(checkoutRequestId, { status, mpesaReceiptNumber, resultDesc }) {
    const existing = await this.findByCheckoutId(checkoutRequestId);
    if (!existing) throw new AppError(`No pending transaction for ${checkoutRequestId}`, 404);
    if (existing.status !== 'pending') return existing; // already finalized — no-op

    const { data, error } = await this._client()
      .from('transactions')
      .update({ status, mpesa_receipt_number: mpesaReceiptNumber, result_desc: resultDesc })
      .eq('checkout_request_id', checkoutRequestId)
      .eq('status', 'pending') // extra guard against a race between two callback deliveries
      .select()
      .maybeSingle();
    if (error) throw new AppError(error.message, 400);
    return data || existing;
  }

  async listByPhone(phoneNumber) {
    const { data, error } = await this._client()
      .from('transactions')
      .select()
      .eq('phone_number', phoneNumber)
      .order('created_at', { ascending: false });
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async listPendingOlderThan(minutes) {
    const cutoff = new Date(Date.now() - minutes * 60 * 1000).toISOString();
    const { data, error } = await this._client()
      .from('transactions')
      .select()
      .eq('status', 'pending')
      .lt('created_at', cutoff);
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Backs the admin Transactions dashboard (admin-web/index.html). */
  async listRecent(limit = 50) {
    const { data, error } = await this._client()
      .from('transactions')
      .select()
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Sum of completed boost payments (account_reference starting with
   * 'BOOST-') — backs the revenue stat on the admin Overview dashboard. */
  async sumCompletedBoostRevenue() {
    const { data, error } = await this._client()
      .from('transactions')
      .select('amount, account_reference, status')
      .eq('status', 'completed')
      .like('account_reference', 'BOOST-%');
    if (error) throw new AppError(error.message, 400);
    return (data || []).reduce((sum, row) => sum + Number(row.amount || 0), 0);
  }
}

module.exports = new TransactionRepository();
