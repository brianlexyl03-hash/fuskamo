const scoutAdminRepository = require('../repositories/scoutAdminRepository');
const asyncHandler = require('../utils/asyncHandler');

exports.listPending = asyncHandler(async (req, res) => {
  const scouts = await scoutAdminRepository.listPending();
  res.status(200).json({ success: true, scouts });
});

exports.approve = asyncHandler(async (req, res) => {
  const scout = await scoutAdminRepository.approve(req.params.id, {
    id: req.adminUser.id,
    email: req.adminUser.email,
    ...req.adminContext,
  });
  res.status(200).json({ success: true, scout });
});

exports.reject = asyncHandler(async (req, res) => {
  await scoutAdminRepository.reject(req.params.id, {
    id: req.adminUser.id,
    email: req.adminUser.email,
    ...req.adminContext,
  });
  res.status(200).json({ success: true });
});
