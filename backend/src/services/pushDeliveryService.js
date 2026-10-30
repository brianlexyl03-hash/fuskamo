const admin = require('firebase-admin');
const env = require('../config/env');
const { getSupabaseAdmin } = require('../config/supabase');
const logger = require('../utils/logger');

let firebaseApp = null;

function getFirebaseMessaging() {
  if (firebaseApp) return admin.messaging(firebaseApp);

  const rawCredentials = env.notifications.firebaseServiceAccountJson;
  if (!rawCredentials) {
    logger.warn('Push delivery requested but FIREBASE_SERVICE_ACCOUNT_JSON is not configured.');
    return null;
  }

  try {
    const credentials = JSON.parse(rawCredentials);
    firebaseApp = admin.apps.find((app) => app.name === 'fuskamo-push')
      || admin.initializeApp({ credential: admin.credential.cert(credentials) }, 'fuskamo-push');
    return admin.messaging(firebaseApp);
  } catch (error) {
    logger.error('Could not initialize Firebase Admin for push delivery.', error);
    return null;
  }
}

/**
 * Send a user-targeted push through Firebase Cloud Messaging.
 * This is an internal backend service; never expose service-role or Firebase
 * credentials to clients. Call it only after the corresponding in-app event
 * has been authorized and persisted.
 *
 * @returns {{sent:number, failed:number, skipped?:boolean}}
 */
async function sendPushToUser({ userId, title, body, data = {} }) {
  if (!userId || typeof title !== 'string' || !title.trim()
      || typeof body !== 'string' || !body.trim()) {
    throw new TypeError('userId, title, and body are required.');
  }

  const messaging = getFirebaseMessaging();
  const supabase = getSupabaseAdmin();
  if (!messaging || !supabase) return { sent: 0, failed: 0, skipped: true };

  const { data: preferences, error: preferenceError } = await supabase
    .from('notification_preferences')
    .select('push_enabled')
    .eq('user_id', userId)
    .limit(1);
  if (preferenceError) throw preferenceError;
  if (preferences?.[0]?.push_enabled === false) return { sent: 0, failed: 0, skipped: true };

  const { data: rows, error: tokenError } = await supabase
    .from('device_tokens')
    .select('token')
    .eq('user_id', userId);
  if (tokenError) throw tokenError;

  const tokens = [...new Set((rows || []).map((row) => row.token).filter(Boolean))];
  if (!tokens.length) return { sent: 0, failed: 0 };

  let sent = 0;
  let failed = 0;
  const invalidTokens = [];

  // FCM multicast requests accept at most 500 registration tokens.
  for (let offset = 0; offset < tokens.length; offset += 500) {
    const chunk = tokens.slice(offset, offset + 500);
    const safeData = Object.fromEntries(
      Object.entries(data).filter(([key, value]) =>
        /^[a-zA-Z0-9_-]{1,40}$/.test(key) && value != null
        && ['string', 'number', 'boolean'].includes(typeof value))
        .map(([key, value]) => [key, String(value).slice(0, 500)])
    );
    const response = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title: title.trim().slice(0, 120), body: body.trim().slice(0, 500) },
      data: safeData,
    });

    sent += response.successCount;
    failed += response.failureCount;
    response.responses.forEach((result, index) => {
      const code = result.error?.code;
      if (code === 'messaging/registration-token-not-registered'
          || code === 'messaging/invalid-registration-token') {
        invalidTokens.push(chunk[index]);
      }
    });
  }

  // Remove expired/invalid tokens so later sends don't repeatedly fail.
  if (invalidTokens.length) {
    const { error } = await supabase.from('device_tokens').delete().in('token', invalidTokens);
    if (error) logger.warn('Could not remove invalid push tokens.', error);
  }

  return { sent, failed };
}

module.exports = { sendPushToUser };
