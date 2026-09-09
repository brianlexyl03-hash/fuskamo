# CSRF — deliberately not implemented, here's why

CSRF protection defends against a malicious *website* tricking a logged-in
browser into submitting a request using the victim's cookies. It's relevant
when: (1) the client is a browser, and (2) auth is carried via cookies.

This backend has neither:
- The only client is the Flutter app (native, not a browser) and Safaricom's
  server-to-server webhook — no browser is ever holding a session cookie for
  this API.
- Auth is a bearer token (`x-api-key` / future JWT `Authorization` header),
  not a cookie. Bearer tokens aren't automatically attached by a browser to
  cross-site requests the way cookies are, so the CSRF attack vector doesn't
  apply.

**When this would need to change:** if a browser-based admin panel is ever
added that uses cookie-based sessions (see `admin-panel/`), CSRF protection
(e.g. `csurf` or double-submit cookie pattern) should be added at that point
for that surface specifically — not for the mobile API.
