const sanitizeHtml = require('sanitize-html');

/** Strips any HTML/script content from string fields in the request body —
 * relevant for freetext fields like strengths/notes that get displayed
 * elsewhere (defense in depth; Flutter's own text rendering doesn't execute
 * HTML either, but never trust the network boundary alone). */
function stripHtml(value) {
  return sanitizeHtml(value, { allowedTags: [], allowedAttributes: {} });
}

function sanitizeBody(req, res, next) {
  if (req.body && typeof req.body === 'object') {
    for (const key of Object.keys(req.body)) {
      if (typeof req.body[key] === 'string') req.body[key] = stripHtml(req.body[key]);
    }
  }
  next();
}

module.exports = { sanitizeBody, stripHtml };
