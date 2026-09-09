const adminAccountsRepository = require('../repositories/adminAccountsRepository');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');
const env = require('../config/env');
const { auditAdminAction } = require('../utils/auditLogger');

exports.listRoles = asyncHandler(async (req, res) => {
  const roles = await adminAccountsRepository.listRoles();
  res.status(200).json({ success: true, roles });
});

exports.list = asyncHandler(async (req, res) => {
  const admins = await adminAccountsRepository.list();
  res.status(200).json({ success: true, admins });
});

exports.invite = asyncHandler(async (req, res) => {
  const { email, displayName, roleId } = req.body || {};
  if (!email || !roleId) throw new AppError('email and roleId are required', 400);

  const admin = await adminAccountsRepository.invite({
    email,
    displayName,
    roleId,
    redirectTo: req.body.redirectTo || env.adminConsoleUrl || undefined,
    createdBy: req.adminUser.id,
  });
  await auditAdminAction(req, 'admin.invite', 'admin_user', admin.id, { email });
  res.status(201).json({ success: true, admin });
});

exports.updateRole = asyncHandler(async (req, res) => {
  const { roleId } = req.body || {};
  if (!roleId) throw new AppError('roleId is required', 400);
  if (req.params.id === req.adminUser.id) {
    throw new AppError('You cannot change your own role — ask another Super Admin', 400);
  }
  const admin = await adminAccountsRepository.updateRole(req.params.id, roleId);
  await auditAdminAction(req, 'admin.role_change', 'admin_user', req.params.id, { roleId });
  res.status(200).json({ success: true, admin });
});

function guardSelf(req) {
  if (req.params.id === req.adminUser.id) {
    throw new AppError('You cannot change your own account status — ask another Super Admin', 400);
  }
}

exports.disable = asyncHandler(async (req, res) => {
  guardSelf(req);
  const admin = await adminAccountsRepository.disable(req.params.id);
  await auditAdminAction(req, 'admin.disable', 'admin_user', req.params.id);
  res.status(200).json({ success: true, admin });
});

exports.suspend = asyncHandler(async (req, res) => {
  guardSelf(req);
  const admin = await adminAccountsRepository.suspend(req.params.id);
  await auditAdminAction(req, 'admin.suspend', 'admin_user', req.params.id);
  res.status(200).json({ success: true, admin });
});

exports.reactivate = asyncHandler(async (req, res) => {
  guardSelf(req);
  const admin = await adminAccountsRepository.reactivate(req.params.id);
  await auditAdminAction(req, 'admin.reactivate', 'admin_user', req.params.id);
  res.status(200).json({ success: true, admin });
});

exports.revoke = asyncHandler(async (req, res) => {
  guardSelf(req);
  const result = await adminAccountsRepository.revoke(req.params.id);
  await auditAdminAction(req, 'admin.revoke', 'admin_user', req.params.id);
  res.status(200).json({ success: true, ...result });
});
