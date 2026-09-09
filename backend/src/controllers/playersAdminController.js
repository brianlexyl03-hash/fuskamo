const playerAdminRepository = require('../repositories/playerAdminRepository');
const asyncHandler = require('../utils/asyncHandler');

exports.listPending = asyncHandler(async (req, res) => {
  const players = await playerAdminRepository.listPending();
  res.status(200).json({ success: true, players });
});

exports.approve = asyncHandler(async (req, res) => {
  const player = await playerAdminRepository.approve(req.params.id, {
    id: req.adminUser.id,
    email: req.adminUser.email,
    ...req.adminContext,
  });
  res.status(200).json({ success: true, data: player });
});

exports.reject = asyncHandler(async (req, res) => {
  const player = await playerAdminRepository.reject(req.params.id, {
    id: req.adminUser.id,
    email: req.adminUser.email,
    ...req.adminContext,
  });
  res.status(200).json({ success: true, data: player });
});
