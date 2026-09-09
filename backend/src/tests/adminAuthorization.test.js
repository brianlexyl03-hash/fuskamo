const test = require('node:test');
const assert = require('node:assert');
const { requirePermission } = require('../authorization/permissions');
const { requireRole } = require('../authorization/rbac');

function mockReqRes(adminUser) {
  const req = { adminUser };
  const res = {};
  let calledNext = false;
  let error = null;
  const next = (err) => {
    calledNext = true;
    error = err;
  };
  return { req, res, next, wasCalled: () => calledNext, getError: () => error };
}

test('requirePermission rejects a request with no admin session at all', () => {
  const mw = requirePermission('players', 'approve');
  const { req, res, next, getError } = mockReqRes(undefined);
  mw(req, res, next);
  const err = getError();
  assert.ok(err, 'expected an error to be passed to next()');
  assert.strictEqual(err.statusCode, 401);
});

test('requirePermission rejects an admin whose role lacks the exact permission', () => {
  const mw = requirePermission('players', 'approve');
  const { req, res, next, getError } = mockReqRes({
    id: 'admin-1',
    role: 'Support',
    permissions: new Set(['players:view', 'scouts:view']), // view-only, no approve
  });
  mw(req, res, next);
  const err = getError();
  assert.ok(err, 'expected requirePermission to reject a view-only role');
  assert.strictEqual(err.statusCode, 403);
});

test('requirePermission allows an admin whose role has the exact permission', () => {
  const mw = requirePermission('players', 'approve');
  const { req, res, next, wasCalled, getError } = mockReqRes({
    id: 'admin-2',
    role: 'Admin',
    permissions: new Set(['players:approve', 'scouts:approve']),
  });
  mw(req, res, next);
  assert.strictEqual(wasCalled(), true);
  assert.ok(!getError(), 'next() should be called with no error');
});

test('requirePermission does not accept a partial/near-miss permission (least privilege)', () => {
  // Having players:view must never satisfy a players:approve requirement —
  // this is the entire point of granular permissions over broad roles.
  const mw = requirePermission('players', 'approve');
  const { req, res, next, getError } = mockReqRes({
    id: 'admin-3',
    role: 'Moderator',
    permissions: new Set(['players:view']),
  });
  mw(req, res, next);
  const err = getError();
  assert.ok(err);
  assert.strictEqual(err.statusCode, 403);
});

test('requireRole rejects when req.adminUser has no role at all', () => {
  const mw = requireRole('Super Admin');
  const { req, res, next, getError } = mockReqRes(undefined);
  mw(req, res, next);
  const err = getError();
  assert.ok(err);
  assert.strictEqual(err.statusCode, 403);
});

test('requireRole rejects a role not in the allowed list', () => {
  const mw = requireRole('Super Admin');
  const { req, res, next, getError } = mockReqRes({ role: 'Admin' });
  mw(req, res, next);
  const err = getError();
  assert.ok(err);
  assert.strictEqual(err.statusCode, 403);
});

test('requireRole allows a role in the allowed list', () => {
  const mw = requireRole('Super Admin', 'Admin');
  const { req, res, next, wasCalled, getError } = mockReqRes({ role: 'Admin' });
  mw(req, res, next);
  assert.strictEqual(wasCalled(), true);
  assert.ok(!getError());
});
