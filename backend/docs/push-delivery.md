# Backend push delivery

`src/services/pushDeliveryService.js` provides a server-side helper for sending a push notification to a specific user.

## Configuration
Set `FIREBASE_SERVICE_ACCOUNT_JSON` in the backend deployment environment to the Firebase service-account JSON contents. Keep it private and server-side only. Configure `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` as well.

## Usage
Call `sendPushToUser({ userId, title, body, data })` from a trusted backend workflow after authorizing and persisting the related notification event. The helper checks `notification_preferences.push_enabled`, sends to registered devices in batches of at most 500, and removes tokens reported by FCM as invalid.

This helper does not create an HTTP endpoint and is not automatically wired to message/follow events yet. The in-app notification record should remain the durable source of truth; push delivery is best-effort.

## Verification
1. Configure Firebase and Supabase environment variables in the backend deployment.
2. Sign in on a real device and verify a token appears in `device_tokens`.
3. Call the helper from an authorized backend workflow and test foreground/background receipt.
4. Disable push in notification preferences and verify delivery is skipped.
5. Verify invalid tokens are removed and no credentials are exposed to clients.
