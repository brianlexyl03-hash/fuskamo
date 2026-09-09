const mpesaService = require('../services/mpesaService');
const transactionRepository = require('../repositories/transactionRepository');
const playerAdminRepository = require('../repositories/playerAdminRepository');
const { auditLog, auditAdminAction } = require('../utils/auditLogger');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../utils/logger');
const AppError = require('../errors/AppError');

const BOOST_HOURS = 48;
const BOOST_PREFIX = 'BOOST-';

exports.initiateStkPush = asyncHandler(async (req, res) => {
  const { phoneNumber, amount, accountReference, transactionDesc } = req.body;
  const result = await mpesaService.initiateStkPush({ phoneNumber, amount, accountReference, transactionDesc });

  // Record immediately as 'pending' — this is what makes duplicate-callback
  // protection and reconciliation possible (see transactionRepository).
  await transactionRepository.createPending({
    checkoutRequestId: result.CheckoutRequestID,
    merchantRequestId: result.MerchantRequestID,
    phoneNumber,
    amount,
    accountReference,
  });

  res.status(200).json({ success: true, data: result });
});

exports.handleCallback = asyncHandler(async (req, res) => {
  const parsed = mpesaService.parseCallback(req.body);

  const existing = await transactionRepository.findByCheckoutId(parsed.checkoutRequestId);
  if (!existing) {
    // No matching transaction WE initiated — reject rather than trust an
    // unsolicited payload. This is the practical substitute for signature
    // validation described in mpesaService.js's file comment.
    logger.warn(`M-Pesa callback for unknown CheckoutRequestID: ${parsed.checkoutRequestId}`);
    return res.status(200).json({ ResultCode: 0, ResultDesc: 'Accepted' }); // still 200 — Safaricom will retry otherwise
  }

  const updated = await transactionRepository.finalize(parsed.checkoutRequestId, {
    status: parsed.success ? 'completed' : 'failed',
    mpesaReceiptNumber: parsed.mpesaReceiptNumber,
    resultDesc: parsed.resultDesc,
  });

  // "Boost this submission" flow — see Flutter's upload_screen.dart. The
  // Flutter app tags the STK push with accountReference = 'BOOST-<playerId>'
  // when initiating it, so on a completed payment we just feature that row.
  // playerAdminRepository.featureUntil() also sends the owner an in-app
  // notification (and SMS/email, per their preferences) — see
  // repositories/playerAdminRepository.js.
  const accountReference = existing.account_reference || '';
  if (parsed.success && accountReference.startsWith(BOOST_PREFIX)) {
    const playerId = accountReference.slice(BOOST_PREFIX.length);
    const until = new Date(Date.now() + BOOST_HOURS * 60 * 60 * 1000).toISOString();
    try {
      await playerAdminRepository.featureUntil(playerId, until);
      logger.info(`Player ${playerId} featured until ${until} (boost payment ${parsed.checkoutRequestId})`);
    } catch (e) {
      logger.warn(`Boost payment succeeded but featuring player ${playerId} failed: ${e.message}`);
    }
  }

  await auditLog({
    actor: 'mpesa-webhook',
    action: parsed.success ? 'payment.completed' : 'payment.failed',
    targetType: 'transaction',
    targetId: parsed.checkoutRequestId,
    metadata: { amount: parsed.amount, receipt: parsed.mpesaReceiptNumber },
  });

  logger.info(`M-Pesa callback processed: ${parsed.checkoutRequestId} → ${updated.status}`);
  res.status(200).json({ ResultCode: 0, ResultDesc: 'Accepted' });
});

exports.getStatus = asyncHandler(async (req, res) => {
  const { checkoutRequestId } = req.params;
  const local = await transactionRepository.findByCheckoutId(checkoutRequestId);
  if (!local) throw new AppError('Transaction not found', 404);

  if (local.status === 'pending') {
    // Live-poll Safaricom rather than only trusting our (possibly stale) row.
    const live = await mpesaService.queryStkPushStatus(checkoutRequestId);
    return res.status(200).json({ success: true, data: { local, live } });
  }
  res.status(200).json({ success: true, data: { local } });
});

exports.getHistory = asyncHandler(async (req, res) => {
  const { phoneNumber } = req.params;
  const history = await transactionRepository.listByPhone(phoneNumber);
  res.status(200).json({ success: true, data: history });
});

exports.refund = asyncHandler(async (req, res) => {
  const { transactionId, amount, remarks } = req.body;

  // transactionId here is OUR internal UUID (transactions.id — the same
  // id admin-web's Transactions table shows), never trusted as Safaricom's
  // own TransactionID directly. Resolving it server-side means a client
  // can't point a refund at a transaction it doesn't actually own, request
  // more than was actually paid, or refund something that was never
  // completed in the first place.
  const transaction = await transactionRepository.findById(transactionId);
  if (!transaction) throw new AppError('No transaction found with that id', 404);
  if (transaction.status !== 'completed' || !transaction.mpesa_receipt_number) {
    throw new AppError('Only a completed payment with a Safaricom receipt can be reversed', 400);
  }
  const refundAmount = amount != null ? Number(amount) : Number(transaction.amount);
  if (refundAmount > Number(transaction.amount)) {
    throw new AppError(
      `Refund amount (${refundAmount}) cannot exceed the original transaction amount (${transaction.amount})`,
      400
    );
  }

  const result = await mpesaService.reverseTransaction({
    transactionId: transaction.mpesa_receipt_number,
    amount: refundAmount,
    remarks,
  });
  await auditAdminAction(req, 'payment.refund_requested', 'transaction', transactionId, {
    amount: refundAmount,
    mpesaReceiptNumber: transaction.mpesa_receipt_number,
    remarks,
  });
  res.status(200).json({ success: true, data: result });
});
