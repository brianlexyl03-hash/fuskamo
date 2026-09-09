const aiService = require('../services/aiService');
const asyncHandler = require('../utils/asyncHandler');

exports.summarizePlayer = asyncHandler(async (req, res) => {
  const { name, position, age, country, club, strengths } = req.body;
  const summary = await aiService.generatePlayerSummary({ name, position, age, country, club, strengths });
  res.status(200).json({ success: true, summary });
});
