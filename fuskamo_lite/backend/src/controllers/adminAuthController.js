const adminAuthRepository = require('../repositories/adminAuthRepository');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');
const { auditAdminAction } = require('../utils/auditLogger');

/** Returns the signed-in admin's own profile + permissions, so the
 * frontend never has to guess what nav items/actions to show — it asks. */
exports.me = asyncHandler(async (req, res) => {
  await adminAuthRepository.recordLogin(req.adminUser.id);
  res.status(200).json({
    success: true,
    admin: {
      id: req.adminUser.id,
      email: req.adminUser.email,
      displayName: req.adminUser.displayName,
      role: req.adminUser.role,
      permissions: Array.from(req.adminUser.permissions),
      mfaEnabled: req.adminUser.mfaEnabled,
    },
  });
});

/** Confirms MFA is enabled for this account. Deliberately requires the
 * calling request's own JWT to already carry aal2 — enforced up in
 * authentication/adminAuth.js's mfa_enabled check would normally block
 * this route too, so instead this route is reachable pre-mfa_enabled but
 * still demands aal2 directly here, proving a real TOTP challenge against
 * Supabase just succeeded. There's no path that sets mfa_enabled=true
 * from a client claim alone. */
exports.confirmMfa = asyncHandler(async (req, res) => {
  if (req.aal !== 'aal2') {
    throw new AppError('Complete a TOTP challenge with Supabase Auth before confirming MFA', 400);
  }
  const result = await adminAuthRepository.confirmMfaEnabled(req.adminUser.id);
  await auditAdminAction(req, 'admin.mfa_enabled', 'admin_user', req.adminUser.id);
  res.status(200).json({ success: true, mfaEnabled: result.mfa_enabled });
});

exports.disableMfa = asyncHandler(async (req, res) => {
  if (req.aal !== 'aal2') {
    throw new AppError('Complete a TOTP challenge with Supabase Auth before disabling MFA', 400);
  }
  const result = await adminAuthRepository.disableMfa(req.adminUser.id);
  await auditAdminAction(req, 'admin.mfa_disabled', 'admin_user', req.adminUser.id);
  res.status(200).json({ success: true, mfaEnabled: result.mfa_enabled });
});

exports.listSessions = asyncHandler(async (req, res) => {
  const sessions = await adminAuthRepository.listMySessions(req.adminUser.id);
  res.status(200).json({
    success: true,
    sessions: sessions.map((s) => ({ ...s, isCurrent: s.session_id === req.adminContext.sessionId })),
  });
});

exports.revokeSession = asyncHandler(async (req, res) => {
  await adminAuthRepository.revokeSession(req.adminUser.id, req.params.id);
  await auditAdminAction(req, 'admin.session_revoke', 'admin_session', req.params.id);
  res.status(200).json({ success: true });
});

exports.revokeAllSessions = asyncHandler(async (req, res) => {
  await adminAuthRepository.revokeAllSessions(req.adminUser.id);
  await auditAdminAction(req, 'admin.session_revoke_all', 'admin_user', req.adminUser.id);
  res.status(200).json({ success: true });
});
