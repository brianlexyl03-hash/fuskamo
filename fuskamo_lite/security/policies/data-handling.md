# Data Handling Policy

- No real names, ages, or countries of real people are ever committed to source code or version control. All such data lives only in the Supabase database, entered at runtime by real users.
- Submitted player data defaults to a private "pending" state and is not publicly queryable until approved.
- Real Supabase credentials are never committed — `.env` is gitignored, and `js/supabase-client.js` ships with placeholder values that must be filled in locally/on the deploy platform, not in the repo.
- Video uploads are stored in a dedicated Supabase Storage bucket, not mixed with app code or static assets.
