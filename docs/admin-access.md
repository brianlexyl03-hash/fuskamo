# Admin access — enterprise RBAC (no shared key)

There is no shared admin key anywhere in this system anymore. Every
administrator has their own Supabase Auth account (email + password,
optionally TOTP MFA), a role, and a set of granular permissions stored in
the database. This replaces the old `ADMIN_API_KEY` design entirely —
that key shipped inside a private app build and had no way to tell *which*
admin acted, no way to revoke one admin without rotating the key for
everyone, and no way to limit what a given admin could do.

## Architecture

- **Roles & permissions** (`database/migrations/013_admin_rbac.sql`):
  `admin_roles`, `admin_permissions` (resource+action pairs, e.g.
  `players:approve`, `admins:manage`), `admin_role_permissions` joins
  them. Seeded roles: **Super Admin** (everything), **Admin** (everything
  except managing other admins), **Moderator** (submissions + content +
  read-only elsewhere), **Support** (read-only everywhere). Create custom
  roles by inserting into `admin_roles` and `admin_role_permissions` — no
  code change needed.
- **Admin accounts** (`admin_users`): one row per `auth.users` admin,
  holding `status` (`active` / `disabled` / `suspended` / `revoked`),
  `role_id`, `mfa_enabled`, lockout fields.
- **Sessions** (`admin_sessions`): tracked per login for "see my active
  sessions" / "sign out everywhere" / per-session revocation.
- **Audit log** (`audit_logs`, expanded by migration 013): every admin
  action records `admin_id`, `ip_address`, `user_agent`, `session_id`,
  timestamp, and action — not just a free-text actor string.

## Why MFA, password reset, and session refresh use Supabase Auth directly

Rather than hand-rolling TOTP/crypto/session storage in this codebase,
`admin-web/` calls Supabase Auth's own APIs directly for sign-in, password
reset, and MFA enrollment/challenge (`supabase.auth.signInWithPassword`,
`resetPasswordForEmail`, `auth.mfa.*`). That's audited infrastructure
Supabase already runs in production for millions of users — reimplementing
it here would be *more* code, more attack surface, and less trustworthy,
not more secure. The backend's job is narrower and just as important:
verify the JWT Supabase issued is real, unexpired, and — when that admin
has MFA enabled — actually carries `aal2` (Authenticator Assurance Level
2), a claim only Supabase itself can set, and only after a real TOTP
challenge succeeded. See `backend/src/authentication/adminAuth.js`.

Concretely: a client can *claim* "I finished MFA setup," but it can't
forge an `aal2` claim in a JWT signed by Supabase. `POST
/api/admin-auth/mfa/confirm` (which flips `admin_users.mfa_enabled` to
true) requires the calling request's own token to already show `aal2` —
proof the TOTP challenge really happened, not a client's word for it.

## Every admin request, step by step

1. `admin-web/` signs in via Supabase Auth → gets a JWT.
2. Every API call sends `Authorization: Bearer <token>` — never a shared
   secret, never a client-supplied header naming a role.
3. `authentication/adminAuth.js` verifies the JWT, loads the matching
   `admin_users` row + role + permissions, checks `status === 'active'`
   and no lockout, and (if `mfa_enabled`) checks `aal2`.
4. `authorization/permissions.js`'s `requirePermission(resource, action)`
   checks the specific permission the route declares — not a broad role
   name. A Support admin's role simply has no `players:approve` row, so no
   code path lets them approve a player, however it's reached.
5. Every mutating action writes to `audit_logs` with the real admin id,
   IP, user agent, and session id (`utils/auditLogger.js`'s
   `auditAdminAction(req, ...)`).

## Managing administrators (Super Admin only)

All under `/api/admin-accounts`, gated by the `admins:view` /
`admins:manage` / `admins:assign_role` permissions (only Super Admin has
these by default):

- **Invite** — creates the Supabase Auth user via `auth.admin
  .inviteUserByEmail` (no password ever passes through this backend or its
  logs) and the matching `admin_users` row with a chosen role. If the DB
  insert fails, the auth user is rolled back automatically.
- **Disable / Suspend** — reversible, blocks login immediately, revokes
  existing sessions. `disabled` = administratively turned off,
  `suspended` = temporarily paused — same mechanics, different label for
  your own bookkeeping.
- **Reactivate** — undoes disable/suspend.
- **Revoke** — permanent. Also deletes the underlying Supabase Auth user
  (`auth.admin.deleteUser`), so there's no login left at all, not just a
  blocked one. The `admin_users` row stays (status `revoked`) so audit-log
  history and foreign keys remain intact.
- A Super Admin cannot change their own role or status through this
  API — ask another Super Admin. (If you're down to one Super Admin and
  need a second, insert the `admin_users` row for them directly via SQL
  with `role_id` set to the Super Admin role's id.)

Self-service (any signed-in admin, their own account only) is under
`/api/admin-auth`: `GET /me` (profile + permissions), `POST
/mfa/confirm` / `/mfa/disable`, `GET /sessions`, `DELETE /sessions/:id`,
`POST /sessions/revoke-all`.

## Setting up your first Super Admin

There's no bootstrap UI for the very first admin (every invite requires
an existing Super Admin to send it) — do it once via SQL after running
migration 013:

```sql
-- 1. Create the Supabase Auth user first (Dashboard → Authentication →
--    Add user, or supabase.auth.admin.createUser via a one-off script),
--    note the returned user id, then:
insert into admin_users (id, email, display_name, role_id, status, created_by)
select '<the-auth-user-id>', 'you@example.com', 'Your Name', id, 'active', null
from admin_roles where name = 'Super Admin';
```
After that, sign in through `admin-web/` and invite everyone else through
the UI — no more manual SQL needed.

## Rate limiting & brute-force protection

`middleware/adminRateLimiter.js`: 30 admin actions/minute, 20
account-management changes/hour, 40 session-management requests/15min —
tighter than the general API limiter (`middleware/rateLimiter.js`), which
still applies underneath. Repeated failed sign-ins are governed by
Supabase Auth's own rate limiting (sign-in happens directly against
Supabase, not through this backend) plus `admin_users.locked_until` /
`failed_login_count`, which `adminAuth.js` checks on every request.

## CSRF

Not applicable — every request here is a bearer token in an
`Authorization` header, never a cookie, so there's no ambient
credential for a malicious page to ride on. Same reasoning as
`docs/csrf-decision.md` for the rest of the API; this note exists so the
question doesn't get re-litigated for admin-web specifically.

## Two consumers of this API

- **`admin-web/`** — the full admin console (this is what you deploy and
  use day to day). See `admin-web/README.md`.
- **The Flutter app** — no longer has any admin surface at all. It was
  removed along with the shared key it depended on. All review happens in
  `admin-web/`.

## Scaling beyond a handful of admins

Nothing here is hardcoded to a small number of admins — roles and
permissions are just rows, `admin_users` is just a table, sessions are
tracked per-row. Hundreds or thousands of admins works the same way one
does. The one thing to revisit at real scale: `adminRateLimiter.js` uses
in-memory rate limiting, which only enforces per-process — if you run more
than one backend instance, point it at Redis (`ioredis` is already a
dependency; swap in `rate-limit-redis`) so limits are enforced across
instances, not per-instance.

## SSO, later

Supabase Auth supports SAML/OIDC providers directly — enabling one is a
Supabase Dashboard configuration change plus a corresponding sign-in
button in `admin-web/`, not a rearchitecture. `admin_users` already keys
off `auth.users.id` regardless of which provider authenticated that user,
so nothing in the RBAC/permissions layer changes when SSO is added.
