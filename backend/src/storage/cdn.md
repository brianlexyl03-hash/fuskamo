# CDN support

Supabase Storage already serves public files through a CDN-backed URL
(Cloudflare-fronted) — no extra CDN configuration needed for player video/
image URLs returned by `getPublicUrl()`. If you outgrow Supabase Storage's
free tier and move assets to S3/R2 directly, that's when adding a CDN
(CloudFront/Cloudflare) becomes a separate task — not needed today.
