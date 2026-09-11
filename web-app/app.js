// FUSKAMO web — full app shell. Mirrors the Flutter app's screens, wired to
// the same Supabase project (RLS-governed) and the same backend API for
// privileged operations (M-Pesa, AI summaries, universal search).

// config.js (gitignored, for local dev) sets window.FUSKAMO_CONFIG. On a
// fresh deploy that file won't exist, so fall back to a one-time browser
// setup screen (same pattern as admin-web) that stores config in
// localStorage — never committed, never sent anywhere but this browser.
const STORED_CFG = localStorage.getItem('fuskamo_web_config');
if (!window.FUSKAMO_CONFIG && STORED_CFG) {
  window.FUSKAMO_CONFIG = JSON.parse(STORED_CFG);
}
if (!window.FUSKAMO_CONFIG || !window.FUSKAMO_CONFIG.SUPABASE_URL) {
  document.getElementById('config-setup').style.display = 'block';
  document.getElementById('app-root').style.display = 'none';
  throw new Error('FUSKAMO_CONFIG missing — showing setup screen');
}

const CFG = window.FUSKAMO_CONFIG;
const sb = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY);

let CURRENT_USER = null;   // Supabase auth user
let CURRENT_PROFILE = null; // row from profiles table

function saveConfigAndReload() {
  const cfg = {
    SUPABASE_URL: document.getElementById('cfg-url').value.trim(),
    SUPABASE_ANON_KEY: document.getElementById('cfg-anon').value.trim(),
    BACKEND_BASE_URL: document.getElementById('cfg-backend').value.trim(),
    BACKEND_API_KEY: document.getElementById('cfg-apikey').value.trim(),
  };
  if (!cfg.SUPABASE_URL || !cfg.SUPABASE_ANON_KEY || !cfg.BACKEND_BASE_URL) {
    alert('Supabase URL, anon key, and backend URL are required.');
    return;
  }
  localStorage.setItem('fuskamo_web_config', JSON.stringify(cfg));
  location.reload();
}

// ---------- Toast ----------
function toast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');

  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.remove('show'), 2400);
}

// ---------- Backend API helper (for privileged / non-Supabase-RLS ops) ----------
async function backendFetch(path, { method = 'GET', body, auth = false } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth) headers['x-api-key'] = CFG.BACKEND_API_KEY;
  const res = await fetch(`${CFG.BACKEND_BASE_URL}${path}`, {
    method, headers, body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(json.message || json.error || `Request failed (${res.status})`);
  return json;
}

// ---------- Router ----------
const ROUTES = [
  'feed', 'discover', 'region', 'search', 'upload', 'scouts', 'scout-apply', 'scout-preferences',
  'groups', 'group', 'create-group', 'group-admin', 'messages', 'conversation', 'message-requests',
  'reels', 'scoreboard', 'achievements', 'notifications', 'notification-preferences',
  'profile', 'public-profile', 'edit-profile', 'account-settings', 'security-settings',
  'story-settings', 'verification', 'moderation', 'analytics', 'mfa-setup',
];
const NAV_TABS = { feed: 'feed', discover: 'discover', groups: 'groups', scouts: 'scouts', profile: 'profile' };

function parseHash() {
  const raw = (location.hash || '#/feed').slice(2); // strip '#/'
  const [path, ...rest] = raw.split('/');
  return { path: path || 'feed', param: rest.join('/') || null };
}

function go(path) { location.hash = '#' + path; }

async function router() {
  if (!CURRENT_USER) { showAuthGate(); return; }
  const { path, param } = parseHash();
  const viewId = 'view-' + path;
  document.querySelectorAll('.view').forEach((v) => v.classList.remove('active'));
  document.querySelectorAll('.nav-tab').forEach((t) => t.classList.remove('active'));
  if (NAV_TABS[path]) {
    const tab = document.querySelector(`.nav-tab[data-tab="${NAV_TABS[path]}"]`);
    if (tab) tab.classList.add('active');
  }
  const el = document.getElementById(viewId);
  if (!el) { go('/feed'); return; }
  el.classList.add('active');
  el.innerHTML = '<div class="spinner"></div>';
  document.getElementById('bottom-nav').style.display = 'flex';
  try {
    await RENDERERS[path](el, param);
  } catch (e) {
    el.innerHTML = `<div class="empty"><div class="big">⚠</div><p>${escapeHtml(e.message || 'Something went wrong loading this screen.')}</p></div>`;
  }
}
window.addEventListener('hashchange', router);

// ---------- Auth ----------
function showAuthGate() {
  document.querySelectorAll('.view').forEach((v) => v.classList.remove('active'));
  document.getElementById('view-auth').classList.add('active');
  document.getElementById('bottom-nav').style.display = 'none';
}
function setAuthTab(tab) {
  document.getElementById('auth-tab-signin').classList.toggle('active', tab === 'signin');
  document.getElementById('auth-tab-signup').classList.toggle('active', tab === 'signup');
  document.getElementById('auth-signin').style.display = tab === 'signin' ? 'block' : 'none';
  document.getElementById('auth-signup').style.display = tab === 'signup' ? 'block' : 'none';
}
async function doSignIn() {
  const email = document.getElementById('signin-email').value.trim();
  const password = document.getElementById('signin-password').value;
  const errEl = document.getElementById('auth-error');
  errEl.textContent = '';
  const { error } = await sb.auth.signInWithPassword({ email, password });
  if (error) { errEl.textContent = error.message; return; }
  await bootAfterAuth();
}
async function doSignUp() {
  const name = document.getElementById('signup-name').value.trim();
  const role = document.getElementById('signup-role').value;
  const email = document.getElementById('signup-email').value.trim();
  const password = document.getElementById('signup-password').value;
  const errEl = document.getElementById('auth-error');
  errEl.textContent = '';
  if (!name) { errEl.textContent = 'Enter your name.'; return; }
  const { data, error } = await sb.auth.signUp({ email, password });
  if (error) { errEl.textContent = error.message; return; }
  if (data.user) {
    await sb.from('profiles').upsert({ user_id: data.user.id, display_name: name, role });
  }
  if (!data.session) {
    errEl.style.color = 'var(--green)';
    errEl.textContent = 'Account created — check your email to confirm, then sign in.';
    return;
  }
  await bootAfterAuth();
}
async function signOut() {
  await sb.auth.signOut();
  CURRENT_USER = null; CURRENT_PROFILE = null;
  showAuthGate();
}
async function ensureProfile() {
  const { data } = await sb.from('profiles').select('*').eq('user_id', CURRENT_USER.id).maybeSingle();
  if (data) { CURRENT_PROFILE = data; return; }
  const { data: created } = await sb.from('profiles').insert({ user_id: CURRENT_USER.id }).select().single();
  CURRENT_PROFILE = created;
}
async function bootAfterAuth() {
  const { data: { user } } = await sb.auth.getUser();
  CURRENT_USER = user;
  if (!user) { showAuthGate(); return; }
  await ensureProfile();
  router();
}

// ---------- Small helpers ----------
function escapeHtml(s) {
  return (s || '').toString().replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function timeAgo(iso) {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000);
  if (s < 60) return `${s}s`;
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  return `${Math.floor(s / 86400)}d`;
}
function initials(name) {
  return (name || '?').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
}
function avatarHtml(url, name, size = '') {
  return url
    ? `<div class="avatar ${size}"><img src="${escapeHtml(url)}" alt=""></div>`
    : `<div class="avatar ${size}">${escapeHtml(initials(name))}</div>`;
}
function badgeHtml(badgeType, verified) {
  if (!verified || !badgeType || badgeType === 'none') return '';
  return `<span class="badge ${badgeType}">✓ ${badgeType}</span>`;
}

// ---------- Boot ----------
(async function init() {
  const { data: { session } } = await sb.auth.getSession();
  if (session) {
    CURRENT_USER = session.user;
    await ensureProfile();
  }
  router();
  sb.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') { CURRENT_USER = null; CURRENT_PROFILE = null; showAuthGate(); }
  });
})();

// ---------- Shared data helpers ----------
// social_posts/social_reels/etc reference auth.users(id) directly, not
// profiles(user_id) — there's no direct FK PostgREST can embed through, so
// author info is always fetched as a second batched lookup like this.
async function fetchProfilesMap(ids) {
  const unique = [...new Set(ids)].filter(Boolean);
  if (!unique.length) return {};
  const { data } = await sb.from('profiles').select('user_id,display_name,username,avatar_url,verified,badge_type').in('user_id', unique);
  const map = {};
  (data || []).forEach((p) => { map[p.user_id] = p; });
  return map;
}
async function myLikedSet(table, idField, ids) {
  if (!CURRENT_USER || !ids.length) return new Set();
  const { data } = await sb.from(table).select(idField).eq('user_id', CURRENT_USER.id).in(idField, ids);
  return new Set((data || []).map((r) => r[idField]));
}

// ---------- Shared card templates ----------
function authorLine(p, when) {
  const name = p ? p.display_name : 'FUSKAMO Member';
  return `<div class="row"><span style="font-weight:600">${escapeHtml(name)}</span>${badgeHtml(p && p.badge_type, p && p.verified)}<span class="muted">· ${timeAgo(when)}</span></div>`;
}
function playerCard(pl) {
  return `<div class="card" onclick="go('/public-profile/${pl.id}')" style="cursor:pointer">
    <div class="row between">
      <div class="row">${avatarHtml(null, pl.name)}<div><div style="font-weight:600">${escapeHtml(pl.name)}</div><div class="muted">${escapeHtml(pl.position)} · ${pl.age}y · ${escapeHtml(pl.country)}</div></div></div>
      ${pl.club ? `<span class="pill">${escapeHtml(pl.club)}</span>` : ''}
    </div>
    ${pl.strengths ? `<p class="muted" style="margin-top:8px">${escapeHtml(pl.strengths)}</p>` : ''}
  </div>`;
}

// ---------- FEED ----------
RENDERERS.feed = async (el) => {
  const { data: posts } = await sb.from('social_posts').select('*').eq('visibility', 'public').eq('status', 'published').is('reply_to_id', null).order('created_at', { ascending: false }).limit(30);
  const profiles = await fetchProfilesMap((posts || []).map((p) => p.author_id));
  const liked = await myLikedSet('social_post_likes', 'post_id', (posts || []).map((p) => p.id));
  el.innerHTML = `
    <div class="card">
      <textarea id="composer-body" placeholder="Share something with the FUSKAMO community..." rows="3"></textarea>
      <input id="composer-media" placeholder="Image/video URL (optional)">
      <button class="btn" onclick="submitPost()">Post</button>
    </div>
    <div id="feed-list">${(posts || []).map((p) => feedPostHtml(p, profiles[p.author_id], liked.has(p.id))).join('') || emptyHtml('No posts yet', 'Be the first to share something.')}</div>`;
};
function feedPostHtml(p, profile, isLiked) {
  return `<div class="card">
    <div class="row between">${authorLine(profile, p.created_at)}</div>
    ${p.body ? `<p style="margin:8px 0">${escapeHtml(p.body)}</p>` : ''}
    ${p.media_url ? (p.media_type === 'external_video' ? `<video src="${escapeHtml(p.media_url)}" controls style="width:100%;border-radius:8px;margin:8px 0"></video>` : `<img src="${escapeHtml(p.media_url)}" style="width:100%;border-radius:8px;margin:8px 0">`) : ''}
    <div class="row" style="gap:18px;margin-top:8px">
      <span onclick="togglePostLike('${p.id}', this)" style="cursor:pointer;color:${isLiked ? 'var(--green)' : 'var(--sub)'}" data-liked="${isLiked}">♥ <span class="cnt">${p.like_count}</span></span>
      <span class="muted">💬 ${p.comment_count}</span>
      <span class="muted">↻ ${p.repost_count}</span>
    </div>
  </div>`;
}
async function submitPost() {
  if (!requireAuth()) return;
  const body = document.getElementById('composer-body').value.trim();
  const media = document.getElementById('composer-media').value.trim();
  if (!body && !media) return toast('Write something or add a media URL.');
  const { error } = await sb.from('social_posts').insert({ author_id: CURRENT_USER.id, body, media_url: media || null, media_type: media ? 'external_video' : 'none' });
  if (error) return toast(error.message);
  toast('Posted');
  router();
}
async function togglePostLike(postId, span) {
  if (!requireAuth()) return;
  const liked = span.dataset.liked === 'true';
  if (liked) await sb.from('social_post_likes').delete().eq('post_id', postId).eq('user_id', CURRENT_USER.id);
  else await sb.from('social_post_likes').insert({ post_id: postId, user_id: CURRENT_USER.id });
  const cnt = span.querySelector('.cnt');
  cnt.textContent = parseInt(cnt.textContent) + (liked ? -1 : 1);
  span.dataset.liked = (!liked).toString();
  span.style.color = liked ? 'var(--sub)' : 'var(--green)';
}
function requireAuth() { if (!CURRENT_USER) { toast('Sign in first'); return false; } return true; }
function emptyHtml(title, sub) { return `<div class="empty"><div class="big">⚽</div><p>${title}</p><p class="muted">${sub}</p></div>`; }

// ---------- DISCOVER ----------
let discoverFilters = { position: '', country: '' };
RENDERERS.discover = async (el) => {
  let q = sb.from('players').select('*').eq('status', 'approved').order('created_at', { ascending: false }).limit(40);
  if (discoverFilters.position) q = q.eq('position', discoverFilters.position);
  if (discoverFilters.country) q = q.eq('country', discoverFilters.country);
  const { data: players } = await q;
  const positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
  el.innerHTML = `
    <h2 style="margin-bottom:12px">Discover Players</h2>
    <div class="row wrap" style="gap:8px;margin-bottom:14px">
      ${positions.map((p) => `<span class="pill ${discoverFilters.position === p ? 'active' : ''}" onclick="setDiscoverFilter('position','${p}')">${p}</span>`).join('')}
      ${discoverFilters.position ? `<span class="pill" onclick="setDiscoverFilter('position','')">Clear</span>` : ''}
    </div>
    <div id="discover-list">${(players || []).map(playerCard).join('') || emptyHtml('No players yet', 'Check back soon or submit one yourself.')}</div>`;
};
function setDiscoverFilter(key, val) { discoverFilters[key] = discoverFilters[key] === val ? '' : val; RENDERERS.discover(document.getElementById('view-discover')); }

// ---------- REGION ----------
RENDERERS.region = async (el, country) => {
  const { data: players } = await sb.from('players').select('*').eq('status', 'approved').eq('country', country).order('created_at', { ascending: false });
  el.innerHTML = `<h2 style="margin-bottom:4px">${escapeHtml(country)}</h2><p class="muted" style="margin-bottom:14px">${(players || []).length} player${(players || []).length === 1 ? '' : 's'}</p>
    ${(players || []).map(playerCard).join('') || emptyHtml('No players from here yet', '')}`;
};

// ---------- SEARCH ----------
RENDERERS.search = async (el) => {
  el.innerHTML = `<input id="search-input" placeholder="Search players, scouts, groups..." oninput="runSearch()" autofocus><div id="search-results"></div>`;
};
let searchTimer;
async function runSearch() {
  clearTimeout(searchTimer);
  const q = document.getElementById('search-input').value.trim();
  const out = document.getElementById('search-results');
  if (!q) { out.innerHTML = ''; return; }
  searchTimer = setTimeout(async () => {
    try {
      const { results } = await backendFetch(`/search?q=${encodeURIComponent(q)}`);
      out.innerHTML = results.length ? results.map((r) => `<div class="card row between">
          <div><div style="font-weight:600">${escapeHtml(r.name)}</div><div class="muted">${escapeHtml(r.meta || '')}</div></div>
          <span class="pill">${r.type}</span>
        </div>`).join('') : emptyHtml('No results', 'Try a different search term.');
    } catch (e) { out.innerHTML = `<p class="muted">${escapeHtml(e.message)}</p>`; }
  }, 300);
}

// ---------- UPLOAD (player submission) ----------
RENDERERS.upload = async (el) => {
  el.innerHTML = `<h2 style="margin-bottom:14px">Submit a Player</h2>
    <label>Full name</label><input id="up-name">
    <label>Position</label>
    <select id="up-position"><option>Goalkeeper</option><option>Defender</option><option>Midfielder</option><option>Forward</option></select>
    <label>Age</label><input id="up-age" type="number">
    <label>Country</label><input id="up-country">
    <label>Club (optional)</label><input id="up-club">
    <label>Jersey number (optional)</label><input id="up-jersey">
    <label>Strengths</label><textarea id="up-strengths" rows="3"></textarea>
    <label>Video URL (optional — a link to existing footage)</label><input id="up-video">
    <button class="btn" onclick="submitPlayer()">Submit for review</button>
    <p class="muted" style="margin-top:10px">Submissions are reviewed by FUSKAMO before appearing on Discover.</p>`;
};
async function submitPlayer() {
  const name = document.getElementById('up-name').value.trim();
  const position = document.getElementById('up-position').value;
  const age = parseInt(document.getElementById('up-age').value);
  const country = document.getElementById('up-country').value.trim();
  if (!name || !age || !country) return toast('Name, age, and country are required.');
  const payload = {
    name, position, age, country,
    club: document.getElementById('up-club').value.trim() || null,
    jersey_number: document.getElementById('up-jersey').value.trim() || null,
    strengths: document.getElementById('up-strengths').value.trim() || null,
    video_url: document.getElementById('up-video').value.trim() || null,
    status: 'pending',
  };
  if (CURRENT_USER) payload.submitted_by = CURRENT_USER.id;
  const { error } = await sb.from('players').insert(payload);
  if (error) return toast(error.message);
  toast('Submitted — pending review');
  go('/profile');
}

// ---------- SCOUTS ----------
RENDERERS.scouts = async (el) => {
  const { data: scouts } = await sb.from('scouts').select('*').eq('verified', true).order('created_at', { ascending: false });
  let myApp = null;
  if (CURRENT_USER) { const { data } = await sb.from('scouts').select('id,verified').eq('user_id', CURRENT_USER.id).maybeSingle(); myApp = data; }
  el.innerHTML = `<h2 style="margin-bottom:14px">Scouts</h2>
    ${!myApp ? `<div class="card"><p style="margin-bottom:10px">Are you a scout, coach, or club rep?</p><button class="btn secondary" onclick="go('/scout-apply')">Apply as a scout</button></div>`
      : (myApp.verified ? `<div class="card"><p>✓ You're a verified scout. <a onclick="go('/scout-preferences')" style="color:var(--green);cursor:pointer">Set your preferences →</a></p></div>` : `<div class="card"><p class="muted">Your scout application is under review.</p></div>`)}
    ${(scouts || []).map((s) => `<div class="card row between">
      <div class="row">${avatarHtml(null, s.name)}<div><div style="font-weight:600">${escapeHtml(s.name)}${badgeHtml(s.badge_type, s.verified)}</div><div class="muted">${escapeHtml(s.organization || '')}</div></div></div>
    </div>`).join('') || emptyHtml('No scouts yet', '')}`;
};
RENDERERS['scout-apply'] = async (el) => {
  if (!requireAuth()) { go('/profile'); return; }
  el.innerHTML = `<h2 style="margin-bottom:14px">Apply as a Scout</h2>
    <label>Name / organization contact</label><input id="sa-name">
    <label>Organization</label><input id="sa-org">
    <button class="btn" onclick="submitScoutApp()">Submit application</button>`;
};
async function submitScoutApp() {
  const name = document.getElementById('sa-name').value.trim();
  const organization = document.getElementById('sa-org').value.trim();
  if (!name) return toast('Name is required.');
  const { error } = await sb.from('scouts').insert({ name, organization, user_id: CURRENT_USER.id, verified: false });
  if (error) return toast(error.message);
  toast('Application submitted');
  go('/scouts');
}
RENDERERS['scout-preferences'] = async (el) => {
  if (!requireAuth()) return;
  const { data: scout } = await sb.from('scouts').select('*').eq('user_id', CURRENT_USER.id).eq('verified', true).maybeSingle();
  if (!scout) { el.innerHTML = emptyHtml('Verified scouts only', 'Your application must be approved first.'); return; }
  el.innerHTML = `<h2 style="margin-bottom:14px">Scouting Preferences</h2>
    <label>Preferred positions (comma-separated)</label><input id="sp-positions" value="${(scout.preferred_positions || []).join(', ')}">
    <label>Preferred countries (comma-separated)</label><input id="sp-countries" value="${(scout.preferred_countries || []).join(', ')}">
    <div class="grid-2"><div><label>Min age</label><input id="sp-age-min" type="number" value="${scout.age_min ?? ''}"></div><div><label>Max age</label><input id="sp-age-max" type="number" value="${scout.age_max ?? ''}"></div></div>
    <label>Preferred foot</label><select id="sp-foot"><option value="">Any</option><option ${scout.preferred_foot === 'left' ? 'selected' : ''}>left</option><option ${scout.preferred_foot === 'right' ? 'selected' : ''}>right</option><option ${scout.preferred_foot === 'both' ? 'selected' : ''}>both</option></select>
    <button class="btn" onclick="saveScoutPrefs('${scout.id}')">Save preferences</button>`;
};
async function saveScoutPrefs(id) {
  const positions = document.getElementById('sp-positions').value.split(',').map((s) => s.trim()).filter(Boolean);
  const countries = document.getElementById('sp-countries').value.split(',').map((s) => s.trim()).filter(Boolean);
  const payload = {
    preferred_positions: positions, preferred_countries: countries,
    age_min: document.getElementById('sp-age-min').value ? parseInt(document.getElementById('sp-age-min').value) : null,
    age_max: document.getElementById('sp-age-max').value ? parseInt(document.getElementById('sp-age-max').value) : null,
    preferred_foot: document.getElementById('sp-foot').value || null,
  };
  const { error } = await sb.from('scouts').update(payload).eq('id', id);
  if (error) return toast(error.message);
  toast('Preferences saved');
}

// ---------- GROUPS ----------
RENDERERS.groups = async (el) => {
  const { data: pub } = await sb.from('groups').select('*').eq('privacy', 'public').order('member_count', { ascending: false }).limit(30);
  let mine = [];
  if (CURRENT_USER) { const { data } = await sb.from('group_members').select('groups(*)').eq('user_id', CURRENT_USER.id); mine = (data || []).map((r) => r.groups).filter(Boolean); }
  el.innerHTML = `<div class="row between" style="margin-bottom:14px"><h2>Groups</h2><button class="btn btn-sm" onclick="go('/create-group')">+ New</button></div>
    ${mine.length ? `<h3 style="margin-bottom:8px">My groups</h3>${mine.map(groupCard).join('')}<div class="divider"></div>` : ''}
    <h3 style="margin-bottom:8px">Discover</h3>
    ${(pub || []).filter((g) => !mine.find((m) => m.id === g.id)).map(groupCard).join('') || emptyHtml('No public groups yet', 'Start one!')}`;
};
function groupCard(g) {
  return `<div class="card" onclick="go('/group/${g.id}')" style="cursor:pointer">
    <div class="row between"><div class="row">${avatarHtml(g.avatar_url, g.name)}<div><div style="font-weight:600">${escapeHtml(g.name)}${g.verified ? ' ✓' : ''}</div><div class="muted">${escapeHtml(g.category)} · ${g.member_count} members</div></div></div></div>
    ${g.description ? `<p class="muted" style="margin-top:8px">${escapeHtml(g.description)}</p>` : ''}
  </div>`;
}
RENDERERS['create-group'] = async (el) => {
  if (!requireAuth()) return;
  el.innerHTML = `<h2 style="margin-bottom:14px">Create a Group</h2>
    <label>Name</label><input id="cg-name">
    <label>Category</label><input id="cg-category" value="General Football">
    <label>Description</label><textarea id="cg-desc" rows="3"></textarea>
    <label>Privacy</label><select id="cg-privacy"><option value="public">Public</option><option value="private">Private</option></select>
    <button class="btn" onclick="createGroup()">Create group</button>`;
};
async function createGroup() {
  const name = document.getElementById('cg-name').value.trim();
  if (!name || name.length < 2) return toast('Name must be at least 2 characters.');
  const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 39) + '-' + Math.random().toString(36).slice(2, 6);
  const { data, error } = await sb.from('groups').insert({
    owner_id: CURRENT_USER.id, name, slug,
    description: document.getElementById('cg-desc').value.trim(),
    category: document.getElementById('cg-category').value.trim() || 'General Football',
    privacy: document.getElementById('cg-privacy').value,
  }).select().single();
  if (error) return toast(error.message);
  await sb.from('group_members').insert({ group_id: data.id, user_id: CURRENT_USER.id, role: 'owner', display_name: CURRENT_PROFILE?.display_name || 'Owner' });
  toast('Group created');
  go('/group/' + data.id);
}
RENDERERS.group = async (el, id) => {
  const { data: group } = await sb.from('groups').select('*').eq('id', id).single();
  if (!group) { el.innerHTML = emptyHtml('Group not found', ''); return; }
  let myMembership = null;
  if (CURRENT_USER) { const { data } = await sb.from('group_members').select('*').eq('group_id', id).eq('user_id', CURRENT_USER.id).maybeSingle(); myMembership = data; }
  const { data: messages } = await sb.from('group_messages').select('*').eq('group_id', id).is('deleted_at', null).order('created_at', { ascending: false }).limit(40);
  const profiles = await fetchProfilesMap((messages || []).map((m) => m.sender_id));
  const canAdmin = myMembership && ['owner', 'host', 'moderator'].includes(myMembership.role);
  el.innerHTML = `<div class="row between" style="margin-bottom:10px">
      <div class="row">${avatarHtml(group.avatar_url, group.name)}<div><h2>${escapeHtml(group.name)}</h2><span class="muted">${group.member_count} members</span></div></div>
      ${canAdmin ? `<button class="btn-sm secondary" onclick="go('/group-admin/${id}')">Manage</button>` : ''}
    </div>
    <p class="muted" style="margin-bottom:12px">${escapeHtml(group.description || '')}</p>
    ${myMembership ? '' : `<button class="btn" onclick="joinGroup('${id}', ${group.join_approval})" style="margin-bottom:14px">${group.join_approval ? 'Request to join' : 'Join group'}</button>`}
    ${myMembership ? `<div class="card"><textarea id="gm-input" placeholder="Message the group..." rows="2"></textarea><button class="btn btn-sm" onclick="sendGroupMessage('${id}')">Send</button></div>` : ''}
    <div style="margin-top:14px">${(messages || []).slice().reverse().map((m) => `<div class="card"><div class="row between">${authorLine(profiles[m.sender_id] || { display_name: m.sender_name }, m.created_at)}</div><p style="margin-top:4px">${escapeHtml(m.content)}</p></div>`).join('') || emptyHtml('No messages yet', 'Say hello!')}</div>`;
};
async function joinGroup(groupId, needsApproval) {
  if (!requireAuth()) return;
  if (needsApproval) {
    const { error } = await sb.from('group_join_requests').insert({ group_id: groupId, user_id: CURRENT_USER.id });
    if (error) return toast(error.message);
    toast('Join request sent');
  } else {
    const { error } = await sb.from('group_members').insert({ group_id: groupId, user_id: CURRENT_USER.id, role: 'member', display_name: CURRENT_PROFILE?.display_name || 'Member' });
    if (error) return toast(error.message);
    toast('Joined group');
  }
  router();
}
async function sendGroupMessage(groupId) {
  const content = document.getElementById('gm-input').value.trim();
  if (!content) return;
  const { error } = await sb.from('group_messages').insert({ group_id: groupId, sender_id: CURRENT_USER.id, sender_name: CURRENT_PROFILE?.display_name || 'Member', content });
  if (error) return toast(error.message);
  router();
}
RENDERERS['group-admin'] = async (el, id) => {
  const { data: requests } = await sb.from('group_join_requests').select('*').eq('group_id', id).eq('status', 'pending');
  const { data: members } = await sb.from('group_members').select('*').eq('group_id', id).order('joined_at');
  const profiles = await fetchProfilesMap([...(requests || []).map((r) => r.user_id), ...(members || []).map((m) => m.user_id)]);
  el.innerHTML = `<h2 style="margin-bottom:14px">Manage Group</h2>
    <h3 style="margin-bottom:8px">Join requests (${(requests || []).length})</h3>
    ${(requests || []).map((r) => `<div class="card row between"><span>${escapeHtml(profiles[r.user_id]?.display_name || 'Member')}</span>
      <div class="row"><button class="btn-sm" onclick="reviewJoinRequest('${r.id}','approved','${id}','${r.user_id}')">Approve</button><button class="btn-sm secondary" onclick="reviewJoinRequest('${r.id}','rejected','${id}','${r.user_id}')">Reject</button></div>
    </div>`).join('') || `<p class="muted" style="margin-bottom:14px">No pending requests.</p>`}
    <h3 style="margin:14px 0 8px">Members (${(members || []).length})</h3>
    ${(members || []).map((m) => `<div class="card row between"><span>${escapeHtml(profiles[m.user_id]?.display_name || m.display_name)}</span><span class="pill">${m.role}</span></div>`).join('')}`;
};
async function reviewJoinRequest(reqId, status, groupId, userId) {
  await sb.from('group_join_requests').update({ status, reviewed_at: new Date().toISOString() }).eq('id', reqId);
  if (status === 'approved') await sb.from('group_members').insert({ group_id: groupId, user_id: userId, role: 'member', display_name: 'Member' });
  toast(status === 'approved' ? 'Approved' : 'Rejected');
  router();
}

// ---------- MESSAGES ----------
RENDERERS.messages = async (el) => {
  if (!requireAuth()) return;
  const { data: reqs } = await sb.from('message_requests').select('*').eq('recipient_id', CURRENT_USER.id).eq('status', 'pending');
  const { data: parts } = await sb.from('direct_conversation_participants').select('conversation_id').eq('user_id', CURRENT_USER.id);
  const convIds = (parts || []).map((p) => p.conversation_id);
  const { data: convs } = convIds.length ? await sb.from('direct_conversations').select('*').in('id', convIds).order('last_message_at', { ascending: false }) : { data: [] };
  const items = [];
  for (const c of (convs || [])) {
    const { data: others } = await sb.from('direct_conversation_participants').select('user_id').eq('conversation_id', c.id).neq('user_id', CURRENT_USER.id);
    const otherId = others && others[0] ? others[0].user_id : null;
    const profiles = otherId ? await fetchProfilesMap([otherId]) : {};
    items.push({ conv: c, other: profiles[otherId] });
  }
  el.innerHTML = `<h2 style="margin-bottom:14px">Messages</h2>
    ${(reqs || []).length ? `<div class="card" onclick="go('/message-requests')" style="cursor:pointer"><div class="row between"><span>Message requests</span><span class="pill">${reqs.length}</span></div></div>` : ''}
    ${items.map((it) => `<div class="card row" onclick="go('/conversation/${it.conv.id}')" style="cursor:pointer">
      ${avatarHtml(it.other?.avatar_url, it.other?.display_name)}
      <div><div style="font-weight:600">${escapeHtml(it.other?.display_name || 'Member')}</div><div class="muted">${it.conv.last_message_at ? timeAgo(it.conv.last_message_at) + ' ago' : 'New conversation'}</div></div>
    </div>`).join('') || emptyHtml('No conversations yet', 'Message someone from their profile.')}`;
};
RENDERERS.conversation = async (el, id) => {
  if (!requireAuth()) return;
  const { data: messages } = await sb.from('direct_messages').select('*').eq('conversation_id', id).is('deleted_at', null).order('created_at', { ascending: true }).limit(100);
  await sb.from('direct_conversation_participants').update({ last_read_at: new Date().toISOString() }).eq('conversation_id', id).eq('user_id', CURRENT_USER.id);
  el.innerHTML = `<div id="conv-thread">${(messages || []).map((m) => `<div class="card" style="${m.sender_id === CURRENT_USER.id ? 'border-color:var(--green)' : ''}"><p>${escapeHtml(m.body)}</p><span class="muted">${timeAgo(m.created_at)} ago</span></div>`).join('') || emptyHtml('Say hello', '')}</div>
    <div class="card" style="position:sticky;bottom:76px"><textarea id="dm-input" rows="2" placeholder="Message..."></textarea><button class="btn btn-sm" onclick="sendDirectMessage('${id}')">Send</button></div>`;
};
async function sendDirectMessage(convId) {
  const body = document.getElementById('dm-input').value.trim();
  if (!body) return;
  const { error } = await sb.from('direct_messages').insert({ conversation_id: convId, sender_id: CURRENT_USER.id, body });
  if (error) return toast(error.message);
  await sb.from('direct_conversations').update({ last_message_at: new Date().toISOString() }).eq('id', convId);
  router();
}
RENDERERS['message-requests'] = async (el) => {
  const { data: reqs } = await sb.from('message_requests').select('*').eq('recipient_id', CURRENT_USER.id).eq('status', 'pending');
  const profiles = await fetchProfilesMap((reqs || []).map((r) => r.sender_id));
  el.innerHTML = `<h2 style="margin-bottom:14px">Message Requests</h2>
    ${(reqs || []).map((r) => `<div class="card row between"><span>${escapeHtml(profiles[r.sender_id]?.display_name || 'Member')}</span>
      <div class="row"><button class="btn-sm" onclick="reviewMessageRequest('${r.id}','accepted','${r.sender_id}')">Accept</button><button class="btn-sm secondary" onclick="reviewMessageRequest('${r.id}','declined','')">Decline</button></div>
    </div>`).join('') || emptyHtml('No requests', '')}`;
};
async function reviewMessageRequest(id, status, senderId) {
  await sb.from('message_requests').update({ status }).eq('id', id);
  if (status === 'accepted' && senderId) {
    const { data: conv } = await sb.from('direct_conversations').insert({ created_by: senderId }).select().single();
    await sb.from('direct_conversation_participants').insert([{ conversation_id: conv.id, user_id: senderId }, { conversation_id: conv.id, user_id: CURRENT_USER.id }]);
  }
  toast('Done');
  router();
}

// ---------- REELS ----------
RENDERERS.reels = async (el) => {
  const { data: reels } = await sb.from('social_reels').select('*').eq('visibility', 'public').eq('status', 'published').order('created_at', { ascending: false }).limit(20);
  const profiles = await fetchProfilesMap((reels || []).map((r) => r.author_id));
  const liked = await myLikedSet('social_reel_likes', 'reel_id', (reels || []).map((r) => r.id));
  el.innerHTML = (reels || []).map((r) => `<div class="reel-card">
      <video src="${escapeHtml(r.video_url)}" ${r.thumbnail_url ? `poster="${escapeHtml(r.thumbnail_url)}"` : ''} controls></video>
      <div class="reel-overlay">${authorLine(profiles[r.author_id], r.created_at)}<p style="margin:4px 0">${escapeHtml(r.caption)}</p>
        <span onclick="toggleReelLike('${r.id}', this)" data-liked="${liked.has(r.id)}" style="color:${liked.has(r.id) ? 'var(--green)' : '#fff'}">♥ <span class="cnt">${r.like_count}</span></span>
      </div>
    </div>`).join('') || emptyHtml('No reels yet', '');
};
async function toggleReelLike(reelId, span) {
  if (!requireAuth()) return;
  const liked = span.dataset.liked === 'true';
  if (liked) await sb.from('social_reel_likes').delete().eq('reel_id', reelId).eq('user_id', CURRENT_USER.id);
  else await sb.from('social_reel_likes').insert({ reel_id: reelId, user_id: CURRENT_USER.id });
  const cnt = span.querySelector('.cnt');
  cnt.textContent = parseInt(cnt.textContent) + (liked ? -1 : 1);
  span.dataset.liked = (!liked).toString();
  span.style.color = liked ? '#fff' : 'var(--green)';
}

// ---------- SCOREBOARD ----------
RENDERERS.scoreboard = async (el) => {
  const { data: season } = await sb.from('scoreboard_seasons').select('*').eq('active', true).maybeSingle();
  if (!season) { el.innerHTML = emptyHtml('No active season', 'Check back when the next season starts.'); return; }
  const { data: rankings } = await sb.from('scoreboard_rankings').select('*').eq('season_id', season.id).order('rank', { ascending: true }).limit(50);
  const profiles = await fetchProfilesMap((rankings || []).map((r) => r.user_id));
  el.innerHTML = `<h2 style="margin-bottom:4px">${escapeHtml(season.name)}</h2><p class="muted" style="margin-bottom:14px">Season scoreboard</p>
    ${(rankings || []).map((r) => `<div class="card row between"><div class="row"><span style="font-family:'Bebas Neue';font-size:20px;width:28px;color:${r.rank <= 3 ? 'var(--amber)' : 'var(--sub)'}">${r.rank}</span>${avatarHtml(profiles[r.user_id]?.avatar_url, profiles[r.user_id]?.display_name, 'sm')}<span>${escapeHtml(profiles[r.user_id]?.display_name || 'Member')}</span></div><span class="muted">${Number(r.score).toFixed(1)}</span></div>`).join('') || emptyHtml('No rankings yet', '')}`;
};

// ---------- ACHIEVEMENTS ----------
RENDERERS.achievements = async (el) => {
  if (!requireAuth()) return;
  const { data: all } = await sb.from('badge_achievements').select('*').eq('active', true);
  const { data: mine } = await sb.from('profile_achievements').select('achievement_id,awarded_at').eq('user_id', CURRENT_USER.id);
  const { data: progress } = await sb.from('achievement_progress').select('*').eq('user_id', CURRENT_USER.id);
  const earnedIds = new Set((mine || []).map((m) => m.achievement_id));
  const progMap = {}; (progress || []).forEach((p) => { progMap[p.achievement_id] = p; });
  el.innerHTML = `<h2 style="margin-bottom:14px">Achievements</h2>
    ${(all || []).map((a) => { const earned = earnedIds.has(a.id); const p = progMap[a.id];
      return `<div class="card row between" style="opacity:${earned ? 1 : 0.6}">
        <div class="row"><span style="font-size:22px">${a.icon}</span><div><div style="font-weight:600">${escapeHtml(a.name)}</div><div class="muted">${escapeHtml(a.description)}</div></div></div>
        ${earned ? '<span class="badge blue">Earned</span>' : (p ? `<span class="muted">${p.progress}/${p.target}</span>` : '')}
      </div>`; }).join('')}`;
};

// ---------- NOTIFICATIONS ----------
RENDERERS.notifications = async (el) => {
  if (!requireAuth()) return;
  const { data: notifs } = await sb.from('notifications').select('*').eq('user_id', CURRENT_USER.id).order('created_at', { ascending: false }).limit(40);
  el.innerHTML = `<div class="row between" style="margin-bottom:14px"><h2>Notifications</h2><span class="pill" onclick="go('/notification-preferences')">Preferences</span></div>
    ${(notifs || []).map((n) => `<div class="card" onclick="markNotifRead('${n.id}', this)" style="cursor:pointer;${n.read ? 'opacity:0.6' : 'border-color:var(--green)'}">
      <div style="font-weight:600">${escapeHtml(n.title)}</div><p class="muted">${escapeHtml(n.body || '')}</p><span class="muted">${timeAgo(n.created_at)} ago</span>
    </div>`).join('') || emptyHtml('You\'re all caught up', '')}`;
};
async function markNotifRead(id, cardEl) {
  await sb.from('notifications').update({ read: true }).eq('id', id);
  cardEl.style.opacity = '0.6';
}
RENDERERS['notification-preferences'] = async (el) => {
  const { data } = await sb.from('notification_preferences').select('*').eq('user_id', CURRENT_USER.id).maybeSingle();
  const prefs = data || { sms_enabled: true, email_enabled: true, push_enabled: true };
  el.innerHTML = `<h2 style="margin-bottom:14px">Notification Preferences</h2>
    ${['sms_enabled', 'email_enabled', 'push_enabled'].map((k) => `<div class="settings-link"><span>${k.replace('_enabled', '').toUpperCase()}</span><input type="checkbox" id="np-${k}" ${prefs[k] ? 'checked' : ''}></div>`).join('')}
    <button class="btn" style="margin-top:14px" onclick="saveNotifPrefs()">Save</button>`;
};
async function saveNotifPrefs() {
  const payload = { user_id: CURRENT_USER.id, sms_enabled: document.getElementById('np-sms_enabled').checked, email_enabled: document.getElementById('np-email_enabled').checked, push_enabled: document.getElementById('np-push_enabled').checked };
  const { error } = await sb.from('notification_preferences').upsert(payload);
  if (error) return toast(error.message);
  toast('Saved');
}

// ---------- PROFILE (mine) ----------
RENDERERS.profile = async (el) => {
  if (!requireAuth()) { showAuthGate(); return; }
  const p = CURRENT_PROFILE || {};
  const { count: followers } = await sb.from('profile_follows').select('*', { count: 'exact', head: true }).eq('followed_id', CURRENT_USER.id);
  const { count: following } = await sb.from('profile_follows').select('*', { count: 'exact', head: true }).eq('follower_id', CURRENT_USER.id);
  el.innerHTML = `<div class="row" style="margin-bottom:14px">${avatarHtml(p.avatar_url, p.display_name, 'lg')}
      <div><h2>${escapeHtml(p.display_name || 'FUSKAMO Member')}${badgeHtml(p.badge_type, p.verified)}</h2><span class="muted">@${escapeHtml(p.username || 'unset')} · ${p.role}</span></div></div>
    <p style="margin-bottom:10px">${escapeHtml(p.bio || '')}</p>
    <div class="row" style="gap:20px;margin-bottom:14px"><span><b>${followers || 0}</b> <span class="muted">followers</span></span><span><b>${following || 0}</b> <span class="muted">following</span></span></div>
    <div class="grid-2" style="margin-bottom:14px">
      <button class="btn secondary" onclick="go('/edit-profile')">Edit profile</button>
      <button class="btn secondary" onclick="go('/analytics')">Analytics</button>
    </div>
    <div class="settings-link" onclick="go('/account-settings')"><span>Account settings</span><span>›</span></div>
    <div class="settings-link" onclick="go('/security-settings')"><span>Security</span><span>›</span></div>
    <div class="settings-link" onclick="go('/story-settings')"><span>New story</span><span>›</span></div>
    <div class="settings-link" onclick="go('/verification')"><span>Get verified</span><span>›</span></div>
    <div class="settings-link" onclick="go('/moderation')"><span>My reports</span><span>›</span></div>
    <div class="settings-link" onclick="go('/mfa-setup')"><span>Two-factor authentication</span><span>›</span></div>
    <button class="btn danger" style="margin-top:16px" onclick="signOut()">Sign out</button>`;
};

// ---------- PUBLIC PROFILE ----------
RENDERERS['public-profile'] = async (el, userId) => {
  const { data: p } = await sb.from('profiles').select('*').eq('user_id', userId).maybeSingle();
  if (!p) { el.innerHTML = emptyHtml('Profile not found', ''); return; }
  let isFollowing = false;
  if (CURRENT_USER) { const { data } = await sb.from('profile_follows').select('*').eq('follower_id', CURRENT_USER.id).eq('followed_id', userId).maybeSingle(); isFollowing = !!data; }
  const { data: posts } = await sb.from('social_posts').select('*').eq('author_id', userId).eq('status', 'published').order('created_at', { ascending: false }).limit(20);
  el.innerHTML = `<div class="row" style="margin-bottom:14px">${avatarHtml(p.avatar_url, p.display_name, 'lg')}<div><h2>${escapeHtml(p.display_name)}${badgeHtml(p.badge_type, p.verified)}</h2><span class="muted">@${escapeHtml(p.username || '')}</span></div></div>
    <p style="margin-bottom:14px">${escapeHtml(p.bio || '')}</p>
    ${CURRENT_USER && CURRENT_USER.id !== userId ? `<div class="grid-2" style="margin-bottom:14px">
      <button class="btn ${isFollowing ? 'secondary' : ''}" onclick="toggleFollow('${userId}', this)">${isFollowing ? 'Following' : 'Follow'}</button>
      <button class="btn secondary" onclick="messageUser('${userId}')">Message</button>
    </div>` : ''}
    <div class="divider"></div>
    ${(posts || []).map((post) => feedPostHtml(post, p, false)).join('') || emptyHtml('No posts yet', '')}`;
};
async function toggleFollow(userId, btn) {
  if (!requireAuth()) return;
  const following = btn.textContent.trim() === 'Following';
  if (following) await sb.from('profile_follows').delete().eq('follower_id', CURRENT_USER.id).eq('followed_id', userId);
  else await sb.from('profile_follows').insert({ follower_id: CURRENT_USER.id, followed_id: userId });
  router();
}
async function messageUser(userId) {
  if (!requireAuth()) return;
  const { data: prefs } = await sb.from('profiles').select('message_requests').eq('user_id', userId).single();
  if (prefs.message_requests === 'nobody') return toast('This person isn\'t accepting messages.');
  const { data: existing } = await sb.from('direct_conversation_participants').select('conversation_id').eq('user_id', CURRENT_USER.id);
  for (const row of (existing || [])) {
    const { data: other } = await sb.from('direct_conversation_participants').select('user_id').eq('conversation_id', row.conversation_id).eq('user_id', userId).maybeSingle();
    if (other) { go('/conversation/' + row.conversation_id); return; }
  }
  const { error } = await sb.from('message_requests').insert({ sender_id: CURRENT_USER.id, recipient_id: userId });
  if (error) return toast(error.message);
  toast('Message request sent');
}

// ---------- EDIT PROFILE ----------
RENDERERS['edit-profile'] = async (el) => {
  const p = CURRENT_PROFILE || {};
  el.innerHTML = `<h2 style="margin-bottom:14px">Edit Profile</h2>
    <label>Display name</label><input id="ep-name" value="${escapeHtml(p.display_name || '')}">
    <label>Username</label><input id="ep-username" value="${escapeHtml(p.username || '')}">
    <label>Bio</label><textarea id="ep-bio" rows="3">${escapeHtml(p.bio || '')}</textarea>
    <label>Avatar URL</label><input id="ep-avatar" value="${escapeHtml(p.avatar_url || '')}">
    <label>Website</label><input id="ep-website" value="${escapeHtml(p.website || '')}">
    <label>Instagram</label><input id="ep-instagram" value="${escapeHtml(p.instagram || '')}">
    <label>Who can message you</label><select id="ep-msgreq"><option value="everyone" ${p.message_requests === 'everyone' ? 'selected' : ''}>Everyone</option><option value="followers" ${p.message_requests === 'followers' ? 'selected' : ''}>Followers</option><option value="nobody" ${p.message_requests === 'nobody' ? 'selected' : ''}>Nobody</option></select>
    <button class="btn" onclick="saveProfile()">Save</button>`;
};
async function saveProfile() {
  const payload = {
    display_name: document.getElementById('ep-name').value.trim(),
    username: document.getElementById('ep-username').value.trim() || null,
    bio: document.getElementById('ep-bio').value.trim(),
    avatar_url: document.getElementById('ep-avatar').value.trim() || null,
    website: document.getElementById('ep-website').value.trim() || null,
    instagram: document.getElementById('ep-instagram').value.trim() || null,
    message_requests: document.getElementById('ep-msgreq').value,
    updated_at: new Date().toISOString(),
  };
  const { error } = await sb.from('profiles').update(payload).eq('user_id', CURRENT_USER.id);
  if (error) return toast(error.message);
  await ensureProfile();
  toast('Profile updated');
  go('/profile');
}

// ---------- ACCOUNT SETTINGS ----------
RENDERERS['account-settings'] = async (el) => {
  el.innerHTML = `<h2 style="margin-bottom:14px">Account</h2>
    <p class="muted" style="margin-bottom:6px">Signed in as</p><p style="margin-bottom:16px">${escapeHtml(CURRENT_USER.email)}</p>
    <label>New password</label><input id="as-password" type="password" placeholder="Leave blank to keep current">
    <button class="btn" onclick="changePassword()">Update password</button>`;
};
async function changePassword() {
  const pw = document.getElementById('as-password').value;
  if (!pw) return toast('Enter a new password.');
  const { error } = await sb.auth.updateUser({ password: pw });
  if (error) return toast(error.message);
  toast('Password updated');
}

// ---------- SECURITY SETTINGS ----------
RENDERERS['security-settings'] = async (el) => {
  const { data } = await sb.from('security_settings').select('*').eq('user_id', CURRENT_USER.id).maybeSingle();
  const s = data || { login_alerts: true, new_device_alerts: true, message_request_filter: true, allow_search_by_email: false, allow_search_by_phone: false };
  const keys = ['login_alerts', 'new_device_alerts', 'message_request_filter', 'allow_search_by_email', 'allow_search_by_phone'];
  el.innerHTML = `<h2 style="margin-bottom:14px">Security</h2>
    ${keys.map((k) => `<div class="settings-link"><span>${k.replace(/_/g, ' ')}</span><input type="checkbox" id="ss-${k}" ${s[k] ? 'checked' : ''}></div>`).join('')}
    <button class="btn" style="margin-top:14px" onclick="saveSecuritySettings()">Save</button>`;
};
async function saveSecuritySettings() {
  const keys = ['login_alerts', 'new_device_alerts', 'message_request_filter', 'allow_search_by_email', 'allow_search_by_phone'];
  const payload = { user_id: CURRENT_USER.id, updated_at: new Date().toISOString() };
  keys.forEach((k) => { payload[k] = document.getElementById('ss-' + k).checked; });
  const { error } = await sb.from('security_settings').upsert(payload);
  if (error) return toast(error.message);
  toast('Saved');
}

// ---------- STORY SETTINGS (new story) ----------
RENDERERS['story-settings'] = async (el) => {
  el.innerHTML = `<h2 style="margin-bottom:14px">New Story</h2>
    <label>Media URL</label><input id="st-media" placeholder="Image or video link">
    <label>Caption</label><textarea id="st-caption" rows="2"></textarea>
    <label>Visible to</label><select id="st-vis"><option value="followers">Followers</option><option value="public">Everyone</option><option value="close_friends">Close friends</option></select>
    <button class="btn" onclick="postStory()">Share story</button>`;
};
async function postStory() {
  const media = document.getElementById('st-media').value.trim();
  if (!media) return toast('Add a media URL.');
  const { error } = await sb.from('social_stories').insert({ author_id: CURRENT_USER.id, media_url: media, caption: document.getElementById('st-caption').value.trim(), visibility: document.getElementById('st-vis').value });
  if (error) return toast(error.message);
  toast('Story posted');
  go('/profile');
}

// ---------- VERIFICATION ----------
RENDERERS.verification = async (el) => {
  const { data: existing } = await sb.from('verification_applications').select('*').eq('user_id', CURRENT_USER.id).order('submitted_at', { ascending: false }).limit(1).maybeSingle();
  if (existing && ['pending', 'needs_more_info'].includes(existing.status)) {
    el.innerHTML = `<h2 style="margin-bottom:10px">Verification</h2><div class="card"><p>Status: <b>${existing.status.replace('_', ' ')}</b></p><p class="muted">Submitted ${timeAgo(existing.submitted_at)} ago.</p>${existing.review_notes ? `<p class="muted">${escapeHtml(existing.review_notes)}</p>` : ''}</div>`;
    return;
  }
  el.innerHTML = `<h2 style="margin-bottom:14px">Get Verified</h2>
    <label>Applying as</label><select id="v-role"><option value="player">Player</option><option value="scout">Scout</option><option value="coach">Coach</option><option value="club">Club</option></select>
    <label>Full / organization name</label><input id="v-name">
    <label>Organization (optional)</label><input id="v-org">
    <label>Country</label><input id="v-country">
    <label>Official website / profile link</label><input id="v-website">
    <label><input type="checkbox" id="v-declare" style="width:auto;margin-right:8px">I confirm this information is accurate</label>
    <button class="btn" onclick="submitVerification()">Submit application</button>`;
};
async function submitVerification() {
  if (!document.getElementById('v-declare').checked) return toast('Please confirm the declaration.');
  const claimed = document.getElementById('v-name').value.trim();
  if (!claimed) return toast('Name is required.');
  const { error } = await sb.from('verification_applications').insert({
    user_id: CURRENT_USER.id, applicant_role: document.getElementById('v-role').value, claimed_name: claimed,
    organization_name: document.getElementById('v-org').value.trim() || null, country: document.getElementById('v-country').value.trim() || null,
    official_website: document.getElementById('v-website').value.trim() || null, declaration_accepted: true,
  });
  if (error) return toast(error.message);
  toast('Application submitted');
  router();
}

// ---------- MODERATION (my reports) ----------
RENDERERS.moderation = async (el) => {
  const { data: reports } = await sb.from('content_reports').select('*').eq('reporter_id', CURRENT_USER.id).order('created_at', { ascending: false });
  el.innerHTML = `<h2 style="margin-bottom:14px">My Reports</h2>
    <div class="card"><p style="margin-bottom:10px">Report a problem you've seen on FUSKAMO.</p>
      <select id="mr-type"><option value="post">Post</option><option value="profile">Profile</option><option value="group">Group</option><option value="message">Message</option></select>
      <input id="mr-target" placeholder="Link or ID of the content">
      <select id="mr-reason"><option value="spam">Spam</option><option value="harassment">Harassment</option><option value="impersonation">Impersonation</option><option value="scam">Scam</option><option value="hate">Hate speech</option><option value="other">Other</option></select>
      <textarea id="mr-details" rows="2" placeholder="Details (optional)"></textarea>
      <button class="btn btn-sm" onclick="fileReport()">Submit report</button>
    </div>
    ${(reports || []).map((r) => `<div class="card row between"><span>${r.target_type} — ${r.reason}</span><span class="pill">${r.status}</span></div>`).join('')}`;
};
async function fileReport() {
  const target = document.getElementById('mr-target').value.trim();
  if (!target) return toast('Add a link or ID for what you\'re reporting.');
  const { error } = await sb.from('content_reports').insert({ reporter_id: CURRENT_USER.id, target_type: document.getElementById('mr-type').value, target_id: target, reason: document.getElementById('mr-reason').value, details: document.getElementById('mr-details').value.trim() });
  if (error) return toast(error.message);
  toast('Report submitted');
  router();
}

// ---------- ANALYTICS ----------
RENDERERS.analytics = async (el) => {
  const since = new Date(Date.now() - 30 * 86400000).toISOString().slice(0, 10);
  const { data: snaps } = await sb.from('creator_daily_snapshots').select('*').eq('creator_id', CURRENT_USER.id).gte('day', since).order('day');
  const totals = (snaps || []).reduce((acc, s) => { ['followers', 'profile_views', 'content_views', 'likes', 'comments', 'shares', 'saves', 'contacts'].forEach((k) => acc[k] = (acc[k] || 0) + s[k]); return acc; }, {});
  const cards = [['Profile views', totals.profile_views], ['Content views', totals.content_views], ['New followers', totals.followers], ['Likes', totals.likes], ['Comments', totals.comments], ['Shares', totals.shares], ['Saves', totals.saves], ['Contacts', totals.contacts]];
  el.innerHTML = `<h2 style="margin-bottom:4px">Creator Analytics</h2><p class="muted" style="margin-bottom:14px">Last 30 days</p>
    <div class="grid-2">${cards.map(([label, val]) => `<div class="card"><div style="font-family:'Bebas Neue';font-size:26px;color:var(--green)">${val || 0}</div><div class="muted">${label}</div></div>`).join('')}</div>`;
};

// ---------- MFA SETUP ----------
RENDERERS['mfa-setup'] = async (el) => {
  const { data: factors } = await sb.auth.mfa.listFactors();
  const verified = (factors?.totp || []).filter((f) => f.status === 'verified');
  if (verified.length) {
    el.innerHTML = `<h2 style="margin-bottom:14px">Two-Factor Authentication</h2><div class="card"><p>✓ Enabled</p><button class="btn danger btn-sm" style="margin-top:10px" onclick="disableMfa('${verified[0].id}')">Disable</button></div>`;
    return;
  }
  el.innerHTML = `<h2 style="margin-bottom:14px">Two-Factor Authentication</h2><p class="muted" style="margin-bottom:14px">Add an authenticator app for extra security.</p><button class="btn" onclick="enrollMfa()">Set up 2FA</button><div id="mfa-qr" style="margin-top:16px"></div>`;
};
async function enrollMfa() {
  const { data, error } = await sb.auth.mfa.enroll({ factorType: 'totp' });
  if (error) return toast(error.message);
  document.getElementById('mfa-qr').innerHTML = `<div class="card"><img src="${data.totp.qr_code}" style="width:100%;border-radius:8px;margin-bottom:10px"><label>Enter the 6-digit code from your app</label><input id="mfa-code" maxlength="6"><button class="btn btn-sm" onclick="confirmMfa('${data.id}')">Confirm</button></div>`;
}
async function confirmMfa(factorId) {
  const code = document.getElementById('mfa-code').value.trim();
  const { data: chal, error: chalErr } = await sb.auth.mfa.challenge({ factorId });
  if (chalErr) return toast(chalErr.message);
  const { error } = await sb.auth.mfa.verify({ factorId, challengeId: chal.id, code });
  if (error) return toast(error.message);
  toast('2FA enabled');
  router();
}
async function disableMfa(factorId) {
  await sb.auth.mfa.unenroll({ factorId });
  toast('2FA disabled');
  router();
}
