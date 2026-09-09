const logger = require('../utils/logger');
const AppError = require('../errors/AppError');

module.exports = (err, req, res, next) => {
  const statusCode = err instanceof AppError ? err.statusCode : 500;
  if (statusCode >= 500) logger.error(`${req.method} ${req.originalUrl}`, err);

  res.status(statusCode).json({
    error: true,
    message: err.isOperational ? err.message : 'Something went wrong. Please try again.',
  });
};
