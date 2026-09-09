const notificationRepository = require('../repositories/notificationRepository');
const asyncHandler = require('../utils/asyncHandler');

exports.list = asyncHandler(async (req, res) => {
  const notifications = await notificationRepository.listForUser(req.params.userId);
  res.status(200).json({ success: true, data: notifications });
});

exports.markRead = asyncHandler(async (req, res) => {
  const notification = await notificationRepository.markRead(req.params.id);
  res.status(200).json({ success: true, data: notification });
});

exports.getPreferences = asyncHandler(async (req, res) => {
  const prefs = await notificationRepository.getPreferences(req.params.userId);
  res.status(200).json({ success: true, data: prefs });
});

exports.setPreferences = asyncHandler(async (req, res) => {
  const prefs = await notificationRepository.setPreferences(req.params.userId, req.body);
  res.status(200).json({ success: true, data: prefs });
});
