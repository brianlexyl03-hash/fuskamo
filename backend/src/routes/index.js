const express = require('express');
const router = express.Router();
const { getSupabaseAdmin } = require('../config/supabase');

// Three distinct probes, matching what most container orchestrators expect:
router.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

// Liveness: is the process itself alive and able to respond at all.
router.get('/live', (req, res) => res.status(200).json({ status: 'alive' }));

// Readiness: is the process ready to serve real traffic (can it reach its
// dependencies?). Orchestrators use this to decide whether to route traffic
// to this instance yet.
router.get('/ready', async (req, res) => {
  const checks = { supabase: false };
  try {
    const client = getSupabaseAdmin();
    if (client) {
      const { error } = await client.from('players').select('id').limit(1);
      checks.supabase = !error;
    }
  } catch (e) {
    checks.supabase = false;
  }
  const ready = Object.values(checks).every(Boolean);
  res.status(ready ? 200 : 503).json({ status: ready ? 'ready' : 'not_ready', checks });
});

router.use('/mpesa', require('./mpesa.routes'));
router.use('/ai', require('./ai.routes'));
router.use('/players-admin', require('./playersAdmin.routes'));
router.use('/scouts-admin', require('./scoutsAdmin.routes'));
router.use('/verification-admin', require('./verificationAdmin.routes'));
router.use('/admin', require('./admin.routes'));
router.use('/admin-auth', require('./adminAuth.routes'));
router.use('/admin-accounts', require('./adminAccounts.routes'));
router.use('/external', require('./external.routes'));
router.use('/search', require('./search.routes'));
// router.use('/notifications', require('./notifications.routes'));
// Removed: this hit an older `notifications` table by trusting :userId
// straight from the URL with no ownership check (apiKeyAuth only — the
// shared app key, not a per-user identity). Confirmed via full search that
// nothing in lib/ ever calls it. The real, actively-used notification
// system is /platform/notifications (platformOperations.routes.js),
// which is properly gated by jwtAuth and scoped to req.user.id against
// the current `notification_events` table. Left the old route file
// in place unreferenced rather than deleting it outright, in case any
// external/legacy caller still expects it to exist — re-enable only
// after adding jwtAuth + an ownership check if that need ever comes up.
router.use('/transactions', require('./transactions.routes'));
router.use('/auth', require('./auth.routes'));
router.use('/discovery', require('./discovery.routes'));
router.use('/discovery/v2', require('./discoveryV2.routes'));
router.use('/recommendations', require('./recommendations.routes'));
router.use('/video', require('./video.routes'));
router.use('/platform', require('./platformOperations.routes'));
router.use('/platform-intelligence', require('./platformIntelligence.routes'));

module.exports = router;
