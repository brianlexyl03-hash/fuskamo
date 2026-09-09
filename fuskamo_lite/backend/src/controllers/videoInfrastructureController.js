const asyncHandler = require('../utils/asyncHandler');
const service = require('../services/videoInfrastructureService');

exports.status = asyncHandler(async (req, res) => {
  const launch = await service.getLaunchStatus();
  res.json({ success: true, launch });
});

exports.prepare = asyncHandler(async (req, res) => {
  const { purpose, sourceUrl, mimeType, sizeBytes, durationMs } = req.body || {};
  const result = await service.prepareAsset(req.user?.id, purpose, { sourceUrl, mimeType, sizeBytes, durationMs });
  res.status(201).json({ success: true, ...result });
});
