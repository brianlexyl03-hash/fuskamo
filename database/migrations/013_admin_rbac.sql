-- Replaces the shared ADMIN_API_KEY entirely. Every administrator now has
-- their own Supabase Auth account (auth.users), a role, and a set of
-- granular permissions. See docs/admin-access.md for the full design.

-- ===== Roles =====
create table if not exists admin_roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  is_system boolean not null default false, -- system roles can't be deleted/renamed
  created_at timestamptz not null default now()
);

-- ===== Permissions catalog (resource + action pairs) =====
create table if not exists admin_permissions (
  id uuid primary key default gen_random_uuid(),
  resource text not null,   -- e.g. 'players', 'scouts', 'transactions', 'admins', 'analytics', 'settings'
  action text not null,     -- e.g. 'view', 'approve', 'reject', 'refund', 'manage', 'export'
  description text not null default '',
  unique (resource, action)
);

create table if not exists admin_role_permissions (
  role_id uuid not null references admin_roles(id) on delete cascade,
  permission_id uuid not null references admin_permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- ===== Admin accounts, one row per auth.users admin =====
create table if not exists admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  display_name text not null default '',
  role_id uuid not null references admin_roles(id),
  status text not null default 'active'
    check (status in ('active', 'disabled', 'suspended', 'revoked')),
  mfa_enabled boolean not null default false,
  failed_login_count integer not null default 0,
  locked_until timestamptz,
  last_login_at timestamptz,
  created_by uuid references admin_users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_admin_users_status on admin_users(status);
create index if not exists idx_admin_users_role on admin_users(role_id);

-- ===== Session tracking, for "logout everywhere" / per-session revocation =====
-- Supabase Auth owns the actual refresh tokens; this table is our own record
-- of active sessions so an admin (or a Super Admin acting on their behalf)
-- can see and revoke them individually. A row is created on login and
-- updated on each authenticated request (last_seen_at); revoke_all calls
-- Supabase's own auth.admin.signOut(userId, 'global') AND marks these rows
-- revoked, so both layers agree.
create table if not exists admin_sessions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references admin_users(id) on delete cascade,
  session_id text not null, -- Supabase JWT 'session_id' (sid) claim
  ip_address inet,
  user_agent text,
  device_label text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  expires_at timestamptz
);
create index if not exists idx_admin_sessions_admin on admin_sessions(admin_id);
create unique index if not exists idx_admin_sessions_session_id on admin_sessions(session_id);

-- ===== Expand audit_logs with structured admin/session/network context =====
-- Keeps the existing `actor` text column (human-readable, e.g. an email)
-- for backward compatibility with rows written before this migration and
-- with non-admin callers of auditLog(); adds proper foreign keys and
-- request metadata for everything written from here on.
alter table audit_logs add column if not exists admin_id uuid references admin_users(id);
alter table audit_logs add column if not exists ip_address inet;
alter table audit_logs add column if not exists user_agent text;
alter table audit_logs add column if not exists session_id text;
create index if not exists idx_audit_logs_admin on audit_logs(admin_id);

-- ===== Row Level Security =====
-- All access to these tables goes through the backend's service-role
-- client, which bypasses RLS by design (same pattern as every other table
-- in this schema — see docs/data-handling.md). RLS is still enabled here,
-- with zero policies, so that if the anon or authenticated key is ever
-- used against these tables by mistake, the default is deny, not "open
-- table because RLS was never turned on."
alter table admin_roles enable row level security;
alter table admin_permissions enable row level security;
alter table admin_role_permissions enable row level security;
alter table admin_users enable row level security;
alter table admin_sessions enable row level security;

-- ===== Seed: permission catalog =====
insert into admin_permissions (resource, action, description) values
  ('users',         'view',    'View end-user accounts'),
  ('users',         'manage',  'Edit or deactivate end-user accounts'),
  ('players',       'view',    'View player submissions'),
  ('players',       'approve', 'Approve or reject pending player submissions'),
  ('scouts',        'view',    'View scout applications'),
  ('scouts',        'approve', 'Approve or reject pending scout applications'),
  ('verification',  'manage',  'Manage identity/organization verification decisions'),
  ('payments',      'view',    'View transactions and payment history'),
  ('payments',      'refund',  'Issue refunds or reverse transactions'),
  ('content',       'view',    'View user-submitted content (reports, flags)'),
  ('content',       'moderate','Remove, hide, or restore content'),
  ('reports',       'view',    'View user-submitted reports/flags'),
  ('reports',       'resolve', 'Resolve or dismiss reports'),
  ('analytics',     'view',    'View platform stats and analytics dashboards'),
  ('analytics',     'export',  'Export analytics/reports data'),
  ('settings',      'manage',  'Change platform-wide settings'),
  ('audit',         'view',    'View the admin audit log'),
  ('admins',        'view',    'View the list of administrator accounts'),
  ('admins',        'manage',  'Create, disable, suspend, reactivate, or revoke administrator accounts'),
  ('admins',        'assign_role', 'Change another administrator''s role')
on conflict (resource, action) do nothing;

-- ===== Seed: default roles =====
insert into admin_roles (name, description, is_system) values
  ('Super Admin', 'Full access to every resource, including managing other administrators.', true),
  ('Admin',       'Full operational access — players, scouts, payments, content, analytics. Cannot manage other admins.', true),
  ('Moderator',   'Reviews and moderates player/scout submissions and user-generated content.', true),
  ('Support',     'Read-only access for handling user support requests.', true)
on conflict (name) do nothing;

-- Super Admin: every permission
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Super Admin'
on conflict do nothing;

-- Admin: everything except admin-account management
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Admin' and p.resource <> 'admins'
on conflict do nothing;

-- Moderator: submissions + content + reports, read-only elsewhere
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Moderator'
  and (
    p.resource in ('players', 'scouts', 'content', 'reports')
    or (p.resource in ('analytics', 'payments', 'users') and p.action = 'view')
  )
on conflict do nothing;

-- Support: view-only across the board
insert into admin_role_permissions (role_id, permission_id)
select r.id, p.id from admin_roles r cross join admin_permissions p
where r.name = 'Support' and p.action = 'view'
on conflict do nothing;
