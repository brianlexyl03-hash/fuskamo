Player video uploads go straight from the Flutter app to Supabase Storage
(see the Flutter app's `PlayerService.submitPlayer`) — they don't pass
through this backend. This folder is here for the day a video needs
server-side processing (e.g. transcoding, thumbnail generation) before
landing in Storage; add a multer-based upload handler here when that's
actually needed.
