// Wraps an async route handler so rejected promises reach errorHandler.js
// instead of crashing the process or hanging the request.
module.exports = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
