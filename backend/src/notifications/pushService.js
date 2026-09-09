const admin = require('firebase-admin');
const env = require('../config/env');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

/**
 * Firebase Cloud Messaging. Requires a real Firebase project — this code
 * is fully wired and correct, but needs FIREBASE_SERVICE_ACCOUNT_JSON (the
 * service account key file's contents, as a single-line JSON string) set
 * in backend/.env, which only you can generate (Firebase Console → Project
 * Settings → Service Accounts → Generate new private key).
 */
let initialized = false;

function ensureInitialized() {
  if (initialized) return;
  if (!env.notifications.firebaseServiceAccountJson) {
    throw new AppError('Push notifications require FIREBASE_SERVICE_ACCOUNT_JSON to be set', 503);
  }
  const credentials = JSON.parse(env.notifications.firebaseServiceAccountJson);
  admin.initializeApp({ credential: admin.credential.cert(credentials) });
  initialized = true;
}

class PushService {
  async sendToDevice(fcmToken, { title, body, data = {} }) {
    ensureInitialized();
    const response = await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
    });
    logger.info(`Push sent: ${response}`);
    return response;
  }
}

module.exports = new PushService();
