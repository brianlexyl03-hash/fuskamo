const axios = require('axios');
const env = require('../config/env');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

/**
 * Safaricom Daraja API integration (M-Pesa).
 *
 * Note on "callback signature validation": Daraja does NOT sign its
 * callback payloads (no HMAC/shared-secret signature scheme like Stripe
 * webhooks provide). Safaricom's own recommended mitigation is IP
 * allowlisting at the infrastructure level (their published IP ranges) —
 * documented in docs/deployment.md. What this code CAN and does verify:
 * that the callback's CheckoutRequestID matches a transaction WE actually
 * initiated and is still 'pending' (see transactionRepository.finalize) —
 * an attacker without that ID can't forge a believable callback even
 * without a cryptographic signature.
 */
class MpesaService {
  constructor() {
    this.baseUrl =
      env.mpesa.env === 'production'
        ? 'https://api.safaricom.co.ke'
        : 'https://sandbox.safaricom.co.ke';
  }

  _assertConfigured() {
    if (!env.isConfigured.mpesa) {
      throw new AppError('M-Pesa is not configured on this server yet — see backend/.env.example', 503);
    }
  }

  async _getAccessToken() {
    this._assertConfigured();
    const credentials = Buffer.from(
      `${env.mpesa.consumerKey}:${env.mpesa.consumerSecret}`
    ).toString('base64');

    const { data } = await axios.get(
      `${this.baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
      { headers: { Authorization: `Basic ${credentials}` } }
    );
    return data.access_token;
  }

  _timestamp() {
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return (
      now.getFullYear().toString() +
      pad(now.getMonth() + 1) +
      pad(now.getDate()) +
      pad(now.getHours()) +
      pad(now.getMinutes()) +
      pad(now.getSeconds())
    );
  }

  _password(timestamp) {
    return Buffer.from(`${env.mpesa.shortcode}${env.mpesa.passkey}${timestamp}`).toString('base64');
  }

  async initiateStkPush({ phoneNumber, amount, accountReference, transactionDesc }) {
    this._assertConfigured();
    const accessToken = await this._getAccessToken();
    const timestamp = this._timestamp();

    const payload = {
      BusinessShortCode: env.mpesa.shortcode,
      Password: this._password(timestamp),
      Timestamp: timestamp,
      TransactionType: 'CustomerPayBillOnline',
      Amount: amount,
      PartyA: phoneNumber,
      PartyB: env.mpesa.shortcode,
      PhoneNumber: phoneNumber,
      CallBackURL: env.mpesa.callbackUrl,
      AccountReference: accountReference || 'FUSKAMO',
      TransactionDesc: transactionDesc || 'FUSKAMO payment',
    };

    const { data } = await axios.post(
      `${this.baseUrl}/mpesa/stkpush/v1/processrequest`,
      payload,
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );

    logger.info(`STK push initiated: ${data.CheckoutRequestID}`);
    return data;
  }

  /** STK Push Query API — lets the app poll "did they pay yet?" instead of
   * only waiting passively for the callback. */
  async queryStkPushStatus(checkoutRequestId) {
    this._assertConfigured();
    const accessToken = await this._getAccessToken();
    const timestamp = this._timestamp();

    const { data } = await axios.post(
      `${this.baseUrl}/mpesa/stkpushquery/v1/query`,
      {
        BusinessShortCode: env.mpesa.shortcode,
        Password: this._password(timestamp),
        Timestamp: timestamp,
        CheckoutRequestID: checkoutRequestId,
      },
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );
    return data;
  }

  /** B2C reversal — refunds a completed payment. Requires a separate
   * "initiator" identity Safaricom issues specifically for B2C/reversal
   * use — see MPESA_INITIATOR_NAME / MPESA_SECURITY_CREDENTIAL in .env.example. */
  async reverseTransaction({ transactionId, amount, remarks }) {
    this._assertConfigured();
    if (!env.mpesa.initiatorName || !env.mpesa.securityCredential) {
      throw new AppError('Refunds require MPESA_INITIATOR_NAME and MPESA_SECURITY_CREDENTIAL to be set', 503);
    }
    const accessToken = await this._getAccessToken();

    const { data } = await axios.post(
      `${this.baseUrl}/mpesa/reversal/v1/request`,
      {
        Initiator: env.mpesa.initiatorName,
        SecurityCredential: env.mpesa.securityCredential,
        CommandID: 'TransactionReversal',
        TransactionID: transactionId,
        Amount: amount,
        ReceiverParty: env.mpesa.shortcode,
        RecieverIdentifierType: '11',
        ResultURL: `${env.mpesa.callbackUrl.replace('/callback', '/reversal-result')}`,
        QueueTimeOutURL: `${env.mpesa.callbackUrl.replace('/callback', '/reversal-timeout')}`,
        Remarks: remarks || 'FUSKAMO refund',
        Occasion: 'Refund',
      },
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );
    return data;
  }

  parseCallback(body) {
    const stkCallback = body?.Body?.stkCallback;
    if (!stkCallback) throw new AppError('Malformed M-Pesa callback payload', 400);

    const success = stkCallback.ResultCode === 0;
    const metadata = {};
    if (success && stkCallback.CallbackMetadata) {
      for (const item of stkCallback.CallbackMetadata.Item) {
        metadata[item.Name] = item.Value;
      }
    }

    return {
      success,
      resultDesc: stkCallback.ResultDesc,
      checkoutRequestId: stkCallback.CheckoutRequestID,
      merchantRequestId: stkCallback.MerchantRequestID,
      amount: metadata.Amount,
      mpesaReceiptNumber: metadata.MpesaReceiptNumber,
      phoneNumber: metadata.PhoneNumber,
    };
  }
}

module.exports = new MpesaService();
