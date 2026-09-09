const { body, param, validationResult } = require('express-validator');
const AppError = require('../errors/AppError');

const stkPushRules = [
  body('phoneNumber')
    .matches(/^254[17]\d{8}$/)
    .withMessage('phoneNumber must be in format 2547XXXXXXXX or 2541XXXXXXXX'),
  body('amount').isInt({ min: 1 }).withMessage('amount must be a positive integer (KES)'),
  body('accountReference').optional().isString().trim().isLength({ max: 50 }),
];

// Money movement — was completely unvalidated before this audit (a
// malformed transactionId or a negative/absurd amount would have reached
// mpesaService.reverseTransaction as-is).
const refundRules = [
  // Our own transactions.id (UUID) — NOT Safaricom's TransactionID. The
  // controller resolves the real Safaricom receipt + validates status +
  // caps the amount against the actual paid amount server-side; a client
  // never gets to name Safaricom's code or an arbitrary amount directly.
  body('transactionId').isUUID().withMessage('transactionId must be a valid UUID (your own transaction record id)'),
  // Optional: omit to refund the full original amount. The real upper
  // bound (can't refund more than was actually paid) is enforced in
  // controllers/mpesaController.js against the stored transaction, not
  // here — this is just a sanity check against nonsense input.
  body('amount').optional().isInt({ min: 1 }).withMessage('amount must be a positive integer (KES) if provided'),
  body('remarks').optional().isString().trim().isLength({ max: 200 }),
];

function validate(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return next(new AppError(errors.array().map((e) => e.msg).join(', '), 400));
  }
  next();
}

module.exports = { stkPushRules, refundRules, validate };
