const externalApiService = require('../services/externalApiService');
const asyncHandler = require('../utils/asyncHandler');

exports.getCountries = asyncHandler(async (req, res) => {
  const countries = await externalApiService.getCountries();
  res.status(200).json({ success: true, data: countries });
});
