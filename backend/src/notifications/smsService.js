const axios = require('axios');
const env = require('../config/env');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

/**
 * Africa's Talking SMS API — chosen over Twilio given the Kenyan user base
 * (better local delivery rates/cost). Real integration against their
 * actual API shape. Get credentials at https://africastalking.com
 */
class SmsService {
  _assertConfigured() {
    if (!env.notifications.atApiKey || !env.notifications.atUsername) {
      throw new AppError('SMS is not configured — set AT_USERNAME / AT_API_KEY in backend/.env', 503);
    }
  }

  async send(phoneNumber, message) {
    this._assertConfigured();
    const url =
      env.notifications.atUsername === 'sandbox'
        ? 'https://api.sandbox.africastalking.com/version1/messaging'
        : 'https://api.africastalking.com/version1/messaging';

    const { data } = await axios.post(
      url,
      new URLSearchParams({ username: env.notifications.atUsername, to: phoneNumber, message }),
      {
        headers: {
          apiKey: env.notifications.atApiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
          Accept: 'application/json',
        },
      }
    );
    logger.info(`SMS sent to ${phoneNumber}`);
    return data;
  }
}

module.exports = new SmsService();
