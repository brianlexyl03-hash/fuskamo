# FUSKAMO Video Architecture — Storage-Gated Launch

FUSKAMO ships the **video product contract** before paying for a large cloud-storage/CDN stack.
The feature is deliberately visible in the UI but cloud video hosting is disabled by default.

## Runtime states

`awaiting_storage -> upload session -> uploading -> processing -> ready`

Failure paths:

`uploading -> failed`
`processing -> failed`
`any active state -> removed`

## Planned pipeline

1. Client requests a `video_asset`.
2. Backend validates authenticated ownership and purpose.
3. Storage provider issues a short-lived upload session.
4. Upload is streamed to object storage; the API never buffers large videos.
5. File signature, MIME type, size and duration are checked.
6. Virus/malware scanning runs before publication.
7. Probe extracts dimensions, duration and codec information.
8. Thumbnail generation creates poster frames.
9. Transcoding creates adaptive renditions.
10. HLS packaging creates a manifest and segment set.
11. Moderation checks run before public publication.
12. CDN playback URL is written to `video_assets.playback_url`.
13. Social objects reference the asset rather than owning storage logic.

## Provider abstraction

The application should not hard-code Supabase Storage, S3, Cloudflare R2, Mux, Bunny, or another provider into social features.
A provider adapter should implement:

- createUploadSession
- completeUpload
- deleteAsset
- getPlaybackUrl
- getThumbnailUrl
- getStorageUsage

This allows FUSKAMO to switch providers without changing posts, stories, reels or player records.

## Current launch gate

`video_storage_policy.enabled = false`

The UI says **Coming Soon** and asks users to support FUSKAMO so resources can be obtained for cloud storage. Contributions do not unlock verification, ranking or private features.

When infrastructure is funded, an authorized deployment operation can enable the provider and the existing schema/job pipeline becomes active.
