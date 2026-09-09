const adminStatsRepository = require('../repositories/adminStatsRepository');
const transactionRepository = require('../repositories/transactionRepository');
const asyncHandler = require('../utils/asyncHandler');

exports.getOverview = asyncHandler(async (req, res) => {
  const [stats, boostRevenueKes] = await Promise.all([
    adminStatsRepository.getStats(),
    transactionRepository.sumCompletedBoostRevenue(),
  ]);
  res.status(200).json({ success: true, stats: { ...stats, boostRevenueKes } });
});

exports.listTransactions = asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const transactions = await transactionRepository.listRecent(limit);
  res.status(200).json({ success: true, transactions });
});

exports.listAuditLogs = asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const logs = await adminStatsRepository.listRecentAuditLogs(limit);
  res.status(200).json({ success: true, logs });
});
