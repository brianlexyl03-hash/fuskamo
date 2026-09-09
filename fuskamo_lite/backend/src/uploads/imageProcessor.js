const sharp = require('sharp');

/** Compresses + resizes an image (e.g. before it lands in Supabase Storage)
 * to keep free-tier storage usage down and feed cards loading fast. */
async function compressImage(buffer, { maxWidth = 1080, quality = 78 } = {}) {
  return sharp(buffer)
    .resize({ width: maxWidth, withoutEnlargement: true })
    .jpeg({ quality })
    .toBuffer();
}

/** Generates a small thumbnail — for feed cards / list views where the
 * full-resolution image isn't needed. */
async function generateThumbnail(buffer, { size = 300 } = {}) {
  return sharp(buffer).resize(size, size, { fit: 'cover' }).jpeg({ quality: 70 }).toBuffer();
}

module.exports = { compressImage, generateThumbnail };
