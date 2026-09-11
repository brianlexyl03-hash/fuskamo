// Runs during `vercel build` (see vercel.json's buildCommand). Writes
// config.js from environment variables set once in the Vercel dashboard
// (Project Settings → Environment Variables), so every visitor's browser
// gets a working config automatically — no manual setup screen needed.
//
// Safe to bake these into the public bundle: SUPABASE_ANON_KEY is
// designed to be public (protected by RLS, not secrecy — see Supabase's
// own docs), and the URLs aren't sensitive. Never put SUPABASE_SERVICE_ROLE_KEY
// or SUPABASE_DB_URL here — those stay backend-only, on Render.
const fs = require('fs');
const path = require('path');

const url = process.env.SUPABASE_URL || '';
const anonKey = process.env.SUPABASE_ANON_KEY || '';
const backendUrl = process.env.BACKEND_BASE_URL || '';

if (!url || !anonKey || !backendUrl) {
  console.warn('[generate-config] SUPABASE_URL / SUPABASE_ANON_KEY / BACKEND_BASE_URL not all set as Vercel env vars — shipping without config.js, visitors will see the one-time setup screen instead.');
} else {
  const content = `window.FUSKAMO_CONFIG = ${JSON.stringify({ SUPABASE_URL: url, SUPABASE_ANON_KEY: anonKey, BACKEND_BASE_URL: backendUrl }, null, 2)};\n`;
  fs.writeFileSync(path.join(__dirname, 'config.js'), content);
  console.log('[generate-config] config.js written from environment variables.');
}
