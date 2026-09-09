const supabase = require('../config/supabase');

/**
 * Video infrastructure deliberately separates the product contract from the
 * storage provider. The application can ship its video UI now while cloud
 * storage/transcoding remains disabled until the project can fund it.
 */
async function getLaunchStatus() {
  const { data, error } = await supabase.rpc('video_launch_status');
  if (error) throw error;
  return data?.[0] || { enabled: false, provider: 'not_configured', max_upload_bytes: 52428800, max_duration_ms: 180000 };
}

async function prepareAsset(userId, purpose, metadata = {}) {
  if (!userId) throw new Error('Authentication required');
  const { data, error } = await supabase.rpc('prepare_video_asset', {
    p_purpose: purpose,
    p_source_url: metadata.sourceUrl || null,
    p_mime_type: metadata.mimeType || null,
    p_size_bytes: metadata.sizeBytes || null,
    p_duration_ms: metadata.durationMs || 0,
  });
  if (error) throw error;
  return { assetId: data, launch: await getLaunchStatus() };
}

module.exports = { getLaunchStatus, prepareAsset };
