const { fileTypeFromBuffer } = require('file-type');
const AppError = require('../errors/AppError');

const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const ALLOWED_VIDEO_TYPES = ['video/mp4', 'video/quicktime'];
const MAX_IMAGE_BYTES = 8 * 1024 * 1024; // 8MB
const MAX_VIDEO_BYTES = 50 * 1024 * 1024; // 50MB, matches the Flutter form's stated limit

/** Validates by actual file CONTENT (magic bytes), not just the filename
 * extension or client-supplied MIME type — both of which a malicious
 * client can lie about. */
async function validateUpload(buffer, { kind }) {
  const detected = await fileTypeFromBuffer(buffer);
  if (!detected) throw new AppError('Could not determine file type', 400);

  if (kind === 'image') {
    if (!ALLOWED_IMAGE_TYPES.includes(detected.mime)) throw new AppError(`Unsupported image type: ${detected.mime}`, 400);
    if (buffer.length > MAX_IMAGE_BYTES) throw new AppError('Image exceeds 8MB limit', 400);
  } else if (kind === 'video') {
    if (!ALLOWED_VIDEO_TYPES.includes(detected.mime)) throw new AppError(`Unsupported video type: ${detected.mime}`, 400);
    if (buffer.length > MAX_VIDEO_BYTES) throw new AppError('Video exceeds 50MB limit', 400);
  }

  return detected;
}

module.exports = { validateUpload, ALLOWED_IMAGE_TYPES, ALLOWED_VIDEO_TYPES };
