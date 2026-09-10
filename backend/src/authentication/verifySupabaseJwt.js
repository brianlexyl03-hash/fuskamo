const jwt = require('jsonwebtoken');
const { jwtVerify, createRemoteJWKSet } = require('jose');
const env = require('../config/env');

/**
 * Verifies a Supabase Auth session JWT.
 *
 * Newer Supabase projects sign session tokens with an asymmetric key
 * (ES256) published at the project's JWKS endpoint
 * (`${SUPABASE_URL}/auth/v1/.well-known/jwks.json`) rather than the old
 * shared HS256 secret (Project Settings → API → JWT Secret). Projects
 * that haven't rotated to the new signing keys still use the legacy
 * HS256 secret. This tries the modern JWKS path first (the default for
 * any project created from mid-2025 onward) and falls back to the
 * legacy HS256 secret so this keeps working either way, with no manual
 * configuration needed to know which mode a given project is in.
 */

let jwks;
function getJwks() {
  if (!jwks) {
    const jwksUrl = new URL('/auth/v1/.well-known/jwks.json', env.supabase.url);
    jwks = createRemoteJWKSet(jwksUrl);
  }
  return jwks;
}

async function verifySupabaseJwt(token) {
  try {
    const { payload } = await jwtVerify(token, getJwks(), {
      issuer: `${env.supabase.url}/auth/v1`,
    });
    return payload;
  } catch (jwksErr) {
    if (env.supabase.jwtSecret) {
      try {
        return jwt.verify(token, env.supabase.jwtSecret, { algorithms: ['HS256'] });
      } catch (hsErr) {
        // Neither method worked — surface the JWKS error, since that's
        // the expected path for current Supabase projects.
        throw jwksErr;
      }
    }
    throw jwksErr;
  }
}

module.exports = { verifySupabaseJwt };
