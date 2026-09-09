# Fuskamo Admin Console

A standalone, single-file admin web app — real per-admin login via
Supabase Auth (no shared key), role-based permissions, MFA, and session
management. No build step: one `index.html`, vanilla JS.

## Why this exists

Originally `docs/admin-access.md` noted a separate admin panel was never
built. It now is — and it uses a full enterprise RBAC system, not a
shared secret. See `docs/admin-access.md` for the complete design.

## Deploy (pick one)

**Vercel (recommended):**
```
cd fuskamo_flutter/admin-web
vercel --prod
```
Or drag the folder into vercel.com/new — it's a static site, no config needed.

**Or just open it locally:** double-click `index.html` — works in any
browser, no server required.

## First-time setup (one-time, per browser)

On first load you're asked for three values, saved locally in that
browser:
- **Supabase URL** — same value as `SUPABASE_URL` in the Flutter app's `.env`
- **Supabase anon key** — the **public anon key**, never the service role
  key. Project Settings → API → `anon` `public`.
- **Backend URL** — your deployed backend, e.g.
  `https://fuskamo-backend.onrender.com`

Then sign in with your own admin email/password (see
`docs/admin-access.md` for how to create the first Super Admin — every
admin after that gets invited from inside this app).

## What it can do

- **Overview** — pending counts, totals, boost revenue
- **Players / Scouts** — approve or reject pending submissions
- **Transactions** — recent M-Pesa history
- **Audit log** — who did what, when, from where (IP + session)
- **My security** — enable/disable TOTP MFA, see and revoke active
  sessions, sign out everywhere
- **Administrators** (Super Admin only) — invite new admins, change
  roles, disable/suspend/reactivate/permanently revoke accounts

Every screen only shows what your permissions actually allow — a
Support-role admin sees Players/Scouts as view-only, a Moderator can't see
Administrators at all, etc.
