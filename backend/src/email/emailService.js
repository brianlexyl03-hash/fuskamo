const nodemailer = require('nodemailer');
const env = require('../config/env');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

/** SMTP-based email (works with any provider — Gmail SMTP for dev, or a
 * transactional provider like Resend/SendGrid's SMTP relay in production). */
class EmailService {
  _transport() {
    if (!env.notifications.smtpHost) {
      throw new AppError('Email is not configured — set SMTP_* vars in backend/.env', 503);
    }
    return nodemailer.createTransport({
      host: env.notifications.smtpHost,
      port: env.notifications.smtpPort,
      secure: env.notifications.smtpPort === 465,
      auth: { user: env.notifications.smtpUser, pass: env.notifications.smtpPass },
    });
  }

  async send({ to, subject, body }) {
    const info = await this._transport().sendMail({
      from: env.notifications.emailFrom || 'no-reply@fuskamo.app',
      to,
      subject,
      text: body,
    });
    logger.info(`Email sent to ${to}: ${info.messageId}`);
    return info;
  }
}

module.exports = new EmailService();
