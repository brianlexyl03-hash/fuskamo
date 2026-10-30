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
  document.getElementById('config-setup').style.display = 'flex';
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
  'story-settings', 'verification', 'moderation', 'analytics', 'mfa-setup', 'post', 'join',
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
  document.querySelectorAll('.view').forEach((v) => v.classList.remove('active', 'screen-arrive'));
  document.querySelectorAll('.nav-tab').forEach((t) => t.classList.remove('active'));
  if (NAV_TABS[path]) {
    const tab = document.querySelector(`.nav-tab[data-tab="${NAV_TABS[path]}"]`);
    if (tab) tab.classList.add('active');
  }
  const el = document.getElementById(viewId);
  if (!el) { go('/feed'); return; }
  el.classList.add('active');
  // Restart a shallow 3D camera move on every route change.
  void el.offsetWidth;
  requestAnimationFrame(() => el.classList.add('screen-arrive'));
  el.innerHTML = '<div class="spinner"></div>';
  document.getElementById('bottom-nav').style.display = 'flex';
  updateNavAvatar();
  try {
    await RENDERERS[path](el, param);
    window.bindFuskamoDepth?.(el);
  } catch (e) {
    el.innerHTML = `<div class="empty"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l10 18H2L12 3z"/><path d="M12 10v4M12 17.5v.01"/></svg><p>${escapeHtml(e.message || 'Something went wrong loading this screen.')}</p></div>`;
  }
}
function updateNavAvatar() {
  const tab = document.querySelector('.nav-tab[data-tab="profile"]');
  if (!tab || !CURRENT_PROFILE?.avatar_url) return;
  const svg = tab.querySelector('svg');
  if (svg && !tab.querySelector('img')) {
    const img = document.createElement('img');
    img.src = CURRENT_PROFILE.avatar_url;
    img.style.cssText = 'width:22px;height:22px;border-radius:50%;object-fit:cover;border:1.5px solid currentColor';
    svg.replaceWith(img);
  }
}
window.addEventListener('hashchange', router);

// ---------- Auth ----------
function showAuthGate() {
  document.querySelectorAll('.view').forEach((v) => v.classList.remove('active', 'screen-arrive'));
  const authView = document.getElementById('view-auth');
  authView.classList.add('active');
  void authView.offsetWidth;
  requestAnimationFrame(() => authView.classList.add('screen-arrive'));
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
  errEl.style.color = 'var(--red)';
  errEl.textContent = '';
  const { error } = await sb.auth.signInWithPassword({ email, password });
  if (error) { errEl.textContent = error.message; return; }
  await bootAfterAuth();
}
function showForgotPassword() {
  const box = document.getElementById('forgot-password-box');
  box.style.display = box.style.display === 'none' ? 'block' : 'none';
  document.getElementById('forgot-email').value = document.getElementById('signin-email').value;
}
async function submitForgotPassword() {
  const email = document.getElementById('forgot-email').value.trim();
  const errEl = document.getElementById('auth-error');
  if (!email) { errEl.style.color = 'var(--red)'; errEl.textContent = 'Enter your email first.'; return; }
  const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin });
  errEl.style.color = error ? 'var(--red)' : 'var(--green)';
  errEl.textContent = error ? error.message : 'Reset link sent — check your email.';
}
async function doResendConfirmation() {
  const email = document.getElementById('signin-email').value.trim();
  const errEl = document.getElementById('auth-error');
  if (!email) { errEl.style.color = 'var(--red)'; errEl.textContent = 'Enter your email above first.'; return; }
  const { error } = await sb.auth.resend({ type: 'signup', email });
  errEl.style.color = error ? 'var(--red)' : 'var(--green)';
  errEl.textContent = error ? error.message : 'Confirmation email resent — check your inbox (and spam).';
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
// ---------- Theme ----------
(function initTheme() {
  const saved = localStorage.getItem('fuskamo_theme');
  if (saved === 'light') document.documentElement.setAttribute('data-theme', 'light');
})();
function toggleTheme() {
  const isLight = document.documentElement.getAttribute('data-theme') === 'light';
  if (isLight) { document.documentElement.removeAttribute('data-theme'); localStorage.setItem('fuskamo_theme', 'dark'); }
  else { document.documentElement.setAttribute('data-theme', 'light'); localStorage.setItem('fuskamo_theme', 'light'); }
}

// ---------- Auth scene parallax ----------
function initAuthParallax() {
  const scene = document.getElementById('auth-scene');
  if (!scene || scene._bound) return;
  scene._bound = true;
  const blobs = scene.querySelectorAll('.auth-blob');
  const juggler = document.querySelector('.juggler');
  function move(x, y) {
    const dx = (x / window.innerWidth - 0.5) * 2;
    const dy = (y / window.innerHeight - 0.5) * 2;
    blobs.forEach((b, i) => { const f = (i + 1) * 10; b.style.transform = `translate(${dx * f}px, ${dy * f}px)`; });
    if (juggler) juggler.style.transform = `translate(${dx * -14}px, ${dy * -14}px)`;
  }
  window.addEventListener('pointermove', (e) => move(e.clientX, e.clientY));
  window.addEventListener('touchmove', (e) => { if (e.touches[0]) move(e.touches[0].clientX, e.touches[0].clientY); }, { passive: true });
  window.addEventListener('deviceorientation', (e) => { if (e.gamma != null) move(window.innerWidth / 2 + e.gamma * 8, window.innerHeight / 2 + (e.beta - 45) * 4); });
}

// ---------- Boot ----------
(async function init() {
  const { data: { session } } = await sb.auth.getSession();
  if (session) {
    CURRENT_USER = session.user;
    await ensureProfile();
  }
  router();
  initAuthParallax();
  // The cinematic welcome owns its own exit/skip timing; do not hide it on Supabase boot.
  sb.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') { CURRENT_USER = null; CURRENT_PROFILE = null; showAuthGate(); }
  });
})();

// ---------- View renderers ----------
const RENDERERS = {};

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
  let mediaStrip = '';
  if (CURRENT_USER) {
    const { data: follows } = await sb.from('profile_follows').select('followed_id').eq('follower_id', CURRENT_USER.id);
    const followedIds = (follows || []).map((f) => f.followed_id);
    const { data: myLikedRows } = await sb.from('social_post_likes').select('post_id').eq('user_id', CURRENT_USER.id).limit(20);
    const likedPostIds = (myLikedRows || []).map((r) => r.post_id);
    let mediaPosts = [];
    if (followedIds.length) { const { data } = await sb.from('social_posts').select('id,media_url,media_type,author_id').in('author_id', followedIds).not('media_url', 'is', null).order('created_at', { ascending: false }).limit(10); mediaPosts = mediaPosts.concat(data || []); }
    if (likedPostIds.length) { const { data } = await sb.from('social_posts').select('id,media_url,media_type,author_id').in('id', likedPostIds).not('media_url', 'is', null).limit(10); mediaPosts = mediaPosts.concat(data || []); }
    const seen = new Set();
    mediaPosts = mediaPosts.filter((m) => !seen.has(m.id) && seen.add(m.id));
    if (mediaPosts.length) {
      mediaStrip = `<div style="margin-bottom:16px"><p class="muted" style="margin-bottom:8px;padding:0 2px">From people you follow</p>
        <div style="display:flex;gap:8px;overflow-x:auto;padding-bottom:4px">
          ${mediaPosts.map((m) => `<div style="flex-shrink:0;width:96px;height:96px;border-radius:var(--r-sm);overflow:hidden;cursor:pointer;background:var(--card)" onclick="go('/post/${m.id}')">
            ${m.media_type === 'external_video' ? `<video src="${escapeHtml(m.media_url)}" style="width:100%;height:100%;object-fit:cover"></video>` : `<img src="${escapeHtml(m.media_url)}" style="width:100%;height:100%;object-fit:cover">`}
          </div>`).join('')}
        </div></div>`;
    }
  }
  el.innerHTML = `
    <section class="field-hero" aria-label="FUSKAMO football talent network">
      <div class="field-hero-copy">
        <p class="eyebrow">THE GLOBAL FOOTBALL NETWORK</p>
        <h1>MAKE YOUR<br>GAME <span>MATTER.</span></h1>
        <p>Find your next opportunity. Put your football journey in front of the people who can move it forward.</p>
        <div class="field-hero-actions">
          <button type="button" class="btn" onclick="go('/discover')">Discover talent</button>
          <button type="button" class="btn secondary" onclick="go('/reels')">Watch reels</button>
        </div>
      </div>
      <div class="field-hero-player" aria-hidden="true"></div>
      <div class="field-hero-index">FUSKAMO / 001 — BUILT FOR THE GAME</div>
    </section>
    <div class="composer-row">
      ${avatarHtml(CURRENT_PROFILE?.avatar_url, CURRENT_PROFILE?.display_name, 'sm')}
      <div style="flex:1">
        <textarea id="composer-body" placeholder="What's happening in football?" rows="2"></textarea>
        <div id="composer-preview"></div>
        <div class="row between" style="margin-top:6px">
          <label for="composer-file" class="icon-btn" style="cursor:pointer;color:var(--green)">
            <svg viewBox="0 0 24 24" width="19" height="19" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M21 16l-5-4-4 3-3-2-6 5"/></svg>
          </label>
          <input type="file" id="composer-file" accept="image/*,video/*" style="display:none" onchange="previewComposerFile()">
          <button class="btn" id="composer-post-btn" style="width:auto;padding:9px 22px" onclick="submitPost()">Post</button>
        </div>
      </div>
    </div>
    ${mediaStrip}
    <div id="feed-list">${(posts || []).map((p) => feedPostHtml(p, profiles[p.author_id], liked.has(p.id))).join('') || emptyHtml('No posts yet', 'Be the first to share something.')}</div>`;
  initFeedVideoAutoplay();
};
let composerFile = null;
function previewComposerFile() {
  const input = document.getElementById('composer-file');
  composerFile = input.files[0] || null;
  const box = document.getElementById('composer-preview');
  if (!composerFile) { box.innerHTML = ''; return; }
  const url = URL.createObjectURL(composerFile);
  const isVideo = composerFile.type.startsWith('video');
  box.innerHTML = `<div style="position:relative;margin-top:8px">
    ${isVideo ? `<video src="${url}" style="width:100%;border-radius:var(--r-sm);max-height:280px" controls></video>` : `<img src="${url}" style="width:100%;border-radius:var(--r-sm);max-height:280px;object-fit:cover">`}
    <button onclick="clearComposerFile()" style="position:absolute;top:6px;right:6px;background:rgba(0,0,0,0.6);border:none;color:#fff;width:26px;height:26px;border-radius:50%;cursor:pointer">✕</button>
  </div>`;
}
function clearComposerFile() {
  composerFile = null;
  document.getElementById('composer-file').value = '';
  document.getElementById('composer-preview').innerHTML = '';
}
async function uploadToStorage(bucket, file) {
  const ext = file.name.split('.').pop();
  const path = `${CURRENT_USER.id}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const { error } = await sb.storage.from(bucket).upload(path, file, { cacheControl: '3600', upsert: false });
  if (error) throw error;
  const { data } = sb.storage.from(bucket).getPublicUrl(path);
  return data.publicUrl;
}
function feedVideoHtml(url) {
  const vid = 'fv' + Math.random().toString(36).slice(2, 9);
  return `<div class="feed-video-wrap" id="wrap-${vid}">
    <video id="${vid}" src="${escapeHtml(url)}" muted playsinline loop class="feed-video" onclick="toggleFeedPlay('${vid}')"></video>
    <div class="feed-play-overlay" id="play-${vid}" onclick="toggleFeedPlay('${vid}')"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg></div>
    <button class="feed-mute-btn" onclick="event.stopPropagation();toggleFeedMute('${vid}')" id="mute-${vid}"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 9v6h4l5 5V4L8 9H4z"/><path d="M17 9l4 6m0-6l-4 6" stroke="#fff" stroke-width="2"/></svg></button>
  </div>`;
}
function toggleFeedPlay(id) {
  const v = document.getElementById(id), overlay = document.getElementById('play-' + id);
  if (v.paused) { v.play().catch(() => {}); overlay.style.display = 'none'; }
  else { v.pause(); overlay.style.display = 'flex'; }
}
function toggleFeedMute(id) {
  const v = document.getElementById(id), btn = document.getElementById('mute-' + id);
  v.muted = !v.muted;
  btn.innerHTML = v.muted
    ? `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 9v6h4l5 5V4L8 9H4z"/><path d="M17 9l4 6m0-6l-4 6" stroke="#fff" stroke-width="2"/></svg>`
    : `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 9v6h4l5 5V4L8 9H4z"/></svg>`;
}
function initFeedVideoAutoplay() {
  const videos = document.querySelectorAll('.feed-video');
  if (!videos.length) return;
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      const v = entry.target;
      const overlay = document.getElementById('play-' + v.id);
      if (entry.isIntersecting && entry.intersectionRatio > 0.6) { v.play().catch(() => {}); if (overlay) overlay.style.display = 'none'; }
      else { v.pause(); if (overlay) overlay.style.display = 'flex'; }
    });
  }, { threshold: [0, 0.6, 1] });
  videos.forEach((v) => observer.observe(v));
}
function feedPostHtml(p, profile, isLiked) {
  return `<div class="tweet-row">
    ${avatarHtml(profile?.avatar_url, profile?.display_name, 'sm')}
    <div style="flex:1;min-width:0">
      <div class="row" style="gap:4px"><span style="font-weight:700">${escapeHtml(profile?.display_name || 'FUSKAMO Member')}</span>${badgeHtml(profile?.badge_type, profile?.verified)}<span class="muted">· ${timeAgo(p.created_at)}</span></div>
      ${p.body ? `<p style="margin:2px 0 6px;cursor:pointer;line-height:1.4" onclick="go('/post/${p.id}')">${escapeHtml(p.body)}</p>` : ''}
      ${p.media_url ? `<div style="position:relative;border-radius:var(--r-md);overflow:hidden;border:1px solid var(--line)" ondblclick="dblTapLike('${p.id}', this)">
        ${p.media_type === 'external_video' ? feedVideoHtml(p.media_url) : `<img src="${escapeHtml(p.media_url)}" style="width:100%;display:block;max-height:420px;object-fit:cover">`}
        <div class="dbl-heart">${HEART_SVG_FILLED}</div>
      </div>` : ''}
      <div class="row" style="gap:28px;margin-top:8px">
        <span class="engage-btn ${isLiked ? 'liked' : ''}" onclick="togglePostLike('${p.id}', this)" data-liked="${isLiked}">${HEART_SVG(isLiked)}<span class="cnt">${p.like_count}</span></span>
        <span class="engage-btn" onclick="go('/post/${p.id}')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.4 8.4 0 0 1-8.9 8.4 9 9 0 0 1-3.6-.8L3 20l1-5a8.3 8.3 0 0 1-1-4A8.4 8.4 0 0 1 11.9 3a8.5 8.5 0 0 1 9.1 8.5z"/></svg>${p.comment_count}</span>
        <span class="engage-btn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M17 2l4 4-4 4"/><path d="M3 11V9a4 4 0 0 1 4-4h14M7 22l-4-4 4-4"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>${p.repost_count}</span>
      </div>
    </div>
  </div>`;
}
function HEART_SVG(filled) { return `<svg viewBox="0 0 24 24" fill="${filled ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20.5s-7.5-4.6-9.8-9.3C.8 7.8 2.4 4.5 5.6 3.7c2-.5 4 .3 5.2 2 .3.4.8.4 1.1 0 1.2-1.7 3.2-2.5 5.2-2 3.2.8 4.8 4.1 3.4 7.5-2.3 4.7-9.8 9.3-9.8 9.3z"/></svg>`; }
const HEART_SVG_FILLED = `<svg viewBox="0 0 24 24" fill="currentColor" stroke="none"><path d="M12 20.5s-7.5-4.6-9.8-9.3C.8 7.8 2.4 4.5 5.6 3.7c2-.5 4 .3 5.2 2 .3.4.8.4 1.1 0 1.2-1.7 3.2-2.5 5.2-2 3.2.8 4.8 4.1 3.4 7.5-2.3 4.7-9.8 9.3-9.8 9.3z"/></svg>`;
async function dblTapLike(postId, wrapEl) {
  if (!requireAuth()) return;
  const { data: existing } = await sb.from('social_post_likes').select('*').eq('post_id', postId).eq('user_id', CURRENT_USER.id).maybeSingle();
  if (!existing) await sb.from('social_post_likes').insert({ post_id: postId, user_id: CURRENT_USER.id });
  const heart = wrapEl.querySelector('.dbl-heart');
  heart.classList.add('pop');
  setTimeout(() => heart.classList.remove('pop'), 700);
  const engageBtn = wrapEl.closest('.card').querySelector('.engage-btn');
  if (engageBtn && engageBtn.dataset.liked !== 'true') {
    engageBtn.dataset.liked = 'true';
    engageBtn.classList.add('liked');
    const cnt = engageBtn.querySelector('.cnt');
    cnt.textContent = parseInt(cnt.textContent) + 1;
  }
}
RENDERERS.join = async (el, code) => {
  if (!requireAuth()) { showAuthGate(); return; }
  el.innerHTML = `<div class="empty"><div class="spinner"></div><p>Joining group...</p></div>`;
  try {
    const { data: groupId, error } = await sb.rpc('redeem_group_invite', { p_code: code });
    if (error) throw error;
    toast('Joined!');
    go('/group/' + groupId);
  } catch (e) {
    el.innerHTML = emptyHtml('Could not join', e.message || 'This invite link may be invalid or expired.');
  }
};
RENDERERS.post = async (el, postId) => {
  const { data: post } = await sb.from('social_posts').select('*').eq('id', postId).maybeSingle();
  if (!post) { el.innerHTML = emptyHtml('Post not found', ''); return; }
  const { data: comments } = await sb.from('social_comments').select('*').eq('post_id', postId).eq('status', 'published').order('created_at', { ascending: true });
  const postAuthor = (await fetchProfilesMap([post.author_id]))[post.author_id];
  const commentProfiles = await fetchProfilesMap((comments || []).map((c) => c.author_id));
  const myLikes = await myLikedSet('social_comment_likes', 'comment_id', (comments || []).map((c) => c.id));
  const liked = (await myLikedSet('social_post_likes', 'post_id', [postId])).has(postId);
  const top = (comments || []).filter((c) => !c.parent_id);
  const repliesOf = (id) => (comments || []).filter((c) => c.parent_id === id);
  const commentHtml = (c) => `<div class="card" style="margin-bottom:8px">
      ${authorLine(commentProfiles[c.author_id], c.created_at)}
      <p style="margin:4px 0">${escapeHtml(c.body)}</p>
      <div class="row" style="gap:14px">
        <span class="engage-btn ${myLikes.has(c.id) ? 'liked' : ''}" style="font-size:12px" onclick="toggleCommentLike('${c.id}', this)" data-liked="${myLikes.has(c.id)}">${HEART_SVG(myLikes.has(c.id))}<span class="cnt">${c.like_count}</span></span>
        <span class="muted" style="cursor:pointer" onclick="showReplyBox('${c.id}')">Reply</span>
      </div>
      <div id="reply-box-${c.id}" style="display:none;margin-top:8px"><textarea id="reply-input-${c.id}" rows="1" placeholder="Write a reply..."></textarea><button class="btn-sm" onclick="submitComment('${postId}', '${c.id}')">Reply</button></div>
      <div style="margin-left:16px;margin-top:6px">${repliesOf(c.id).map(commentHtml).join('')}</div>
    </div>`;
  el.innerHTML = `<div class="card">
      ${authorLine(postAuthor, post.created_at)}
      ${post.body ? `<p style="margin:8px 0">${escapeHtml(post.body)}</p>` : ''}
      ${post.media_url ? (post.media_type === 'external_video' ? `<div style="border-radius:var(--r-md);overflow:hidden;border:1px solid var(--line);margin:8px 0">${feedVideoHtml(post.media_url)}</div>` : `<img src="${escapeHtml(post.media_url)}" style="width:100%;border-radius:var(--r-sm);margin:8px 0">`) : ''}
      <div class="row" style="gap:18px;margin-top:8px">
        <span class="engage-btn ${liked ? 'liked' : ''}" onclick="togglePostLike('${post.id}', this)" data-liked="${liked}">${HEART_SVG(liked)}<span class="cnt">${post.like_count}</span></span>
        <span class="muted">${comments.length} comment${comments.length === 1 ? '' : 's'}</span>
      </div>
    </div>
    <div class="card"><textarea id="new-comment-input" rows="2" placeholder="Add a comment..."></textarea><button class="btn btn-sm" onclick="submitComment('${postId}', null)">Comment</button></div>
    <div id="comments-list">${top.map(commentHtml).join('') || emptyHtml('No comments yet', 'Start the conversation.')}</div>`;
  initFeedVideoAutoplay();
};
function showReplyBox(commentId) {
  const box = document.getElementById('reply-box-' + commentId);
  box.style.display = box.style.display === 'none' ? 'block' : 'none';
}
async function submitComment(postId, parentId) {
  if (!requireAuth()) return;
  const inputId = parentId ? `reply-input-${parentId}` : 'new-comment-input';
  const body = document.getElementById(inputId).value.trim();
  if (!body) return toast('Write something first.');
  const { error } = await sb.from('social_comments').insert({ post_id: postId, author_id: CURRENT_USER.id, parent_id: parentId, body });
  if (error) return toast(error.message);
  router();
}
async function toggleCommentLike(commentId, span) {
  if (!requireAuth()) return;
  const liked = span.dataset.liked === 'true';
  if (liked) await sb.from('social_comment_likes').delete().eq('comment_id', commentId).eq('user_id', CURRENT_USER.id);
  else await sb.from('social_comment_likes').insert({ comment_id: commentId, user_id: CURRENT_USER.id });
  router();
}
async function submitPost() {
  if (!requireAuth()) return;
  const body = document.getElementById('composer-body').value.trim();
  if (!body && !composerFile) return toast('Write something or add a photo/video.');
  const btn = document.getElementById('composer-post-btn');
  btn.disabled = true; btn.textContent = 'Posting...';
  try {
    let mediaUrl = null, mediaType = 'none';
    if (composerFile) {
      mediaUrl = await uploadToStorage('post-media', composerFile);
      mediaType = composerFile.type.startsWith('video') ? 'external_video' : 'image';
    }
    const { error } = await sb.from('social_posts').insert({ author_id: CURRENT_USER.id, body, media_url: mediaUrl, media_type: mediaType });
    if (error) throw error;
    composerFile = null;
    toast('Posted');
    router();
  } catch (e) {
    toast(e.message || 'Failed to post');
    btn.disabled = false; btn.textContent = 'Post';
  }
}
async function togglePostLike(postId, span) {
  if (!requireAuth()) return;
  const liked = span.dataset.liked === 'true';
  if (liked) await sb.from('social_post_likes').delete().eq('post_id', postId).eq('user_id', CURRENT_USER.id);
  else await sb.from('social_post_likes').insert({ post_id: postId, user_id: CURRENT_USER.id });
  const cnt = span.querySelector('.cnt');
  cnt.textContent = parseInt(cnt.textContent) + (liked ? -1 : 1);
  span.dataset.liked = (!liked).toString();
  span.classList.toggle('liked', !liked);
}
function requireAuth() { if (!CURRENT_USER) { toast('Sign in first'); return false; } return true; }
function emptyHtml(title, sub) { return `<div class="empty"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7l3.5 2.5-1.3 4.2h-4.4L8.5 9.5 12 7zM12 3v4M4.6 8l3.9 1.5M4.6 16l3.9-1.5M19.4 8l-3.9 1.5M19.4 16l-3.9-1.5M12 21v-4"/></svg><p>${title}</p><p class="muted">${sub}</p></div>`; }

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
    <label for="up-video-file" class="btn secondary" style="cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:10px">
      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><polygon points="10,9 16,12 10,15"/></svg> Upload footage
    </label>
    <input type="file" id="up-video-file" accept="video/*" style="display:none" onchange="previewUploadVideo()">
    <div id="up-video-preview"></div>
    <p class="muted" style="margin:-4px 0 10px">or paste a link instead:</p>
    <input id="up-video" placeholder="https://...">
    <button class="btn" id="up-submit-btn" onclick="submitPlayer()">Submit for review</button>
    <p class="muted" style="margin-top:10px">Submissions are reviewed by FUSKAMO before appearing on Discover.</p>`;
};
let uploadVideoFile = null;
function previewUploadVideo() {
  uploadVideoFile = document.getElementById('up-video-file').files[0] || null;
  const box = document.getElementById('up-video-preview');
  box.innerHTML = uploadVideoFile ? `<video src="${URL.createObjectURL(uploadVideoFile)}" style="width:100%;border-radius:var(--r-sm);max-height:240px;margin-bottom:10px" controls></video>` : '';
}
async function submitPlayer() {
  const name = document.getElementById('up-name').value.trim();
  const position = document.getElementById('up-position').value;
  const age = parseInt(document.getElementById('up-age').value);
  const country = document.getElementById('up-country').value.trim();
  if (!name || !age || !country) return toast('Name, age, and country are required.');
  const btn = document.getElementById('up-submit-btn');
  btn.disabled = true; btn.textContent = 'Submitting...';
  try {
    let videoUrl = document.getElementById('up-video').value.trim() || null;
    if (uploadVideoFile) {
      if (!requireAuth()) { btn.disabled = false; btn.textContent = 'Submit for review'; return; }
      videoUrl = await uploadToStorage('player-videos', uploadVideoFile);
    }
    const payload = {
      name, position, age, country,
      club: document.getElementById('up-club').value.trim() || null,
      jersey_number: document.getElementById('up-jersey').value.trim() || null,
      strengths: document.getElementById('up-strengths').value.trim() || null,
      video_url: videoUrl,
      status: 'pending',
    };
    if (CURRENT_USER) payload.submitted_by = CURRENT_USER.id;
    const { error } = await sb.from('players').insert(payload);
    if (error) throw error;
    uploadVideoFile = null;
    toast('Submitted — pending review');
    go('/profile');
  } catch (e) { toast(e.message || 'Submission failed'); btn.disabled = false; btn.textContent = 'Submit for review'; }
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
async function fetchHostsForGroups(groupIds) {
  if (!groupIds.length) return {};
  const { data } = await sb.from('group_members').select('group_id,user_id,role').in('group_id', groupIds).in('role', ['owner', 'host']);
  const byGroup = {};
  (data || []).forEach((m) => { (byGroup[m.group_id] = byGroup[m.group_id] || []).push(m.user_id); });
  const profiles = await fetchProfilesMap((data || []).map((m) => m.user_id));
  return { byGroup, profiles };
}
RENDERERS.groups = async (el) => {
  const { data: pub } = await sb.from('groups').select('*').eq('privacy', 'public').order('member_count', { ascending: false }).limit(30);
  let mine = [];
  if (CURRENT_USER) { const { data } = await sb.from('group_members').select('groups(*)').eq('user_id', CURRENT_USER.id); mine = (data || []).map((r) => r.groups).filter(Boolean); }
  const discover = (pub || []).filter((g) => !mine.find((m) => m.id === g.id));
  const allGroups = [...mine, ...discover];
  const { byGroup = {}, profiles = {} } = await fetchHostsForGroups(allGroups.map((g) => g.id));
  el.innerHTML = `<header class="section-masthead">
      <div><p class="eyebrow">FUSKAMO / COMMUNITY</p><h2>Find your people.</h2><p class="muted">Build a squad, share knowledge and keep the game moving.</p></div>
      <button class="btn btn-sm" onclick="go('/create-group')">Create group</button>
    </header>
    ${mine.length ? `<h3 class="section-label">Your groups</h3>${mine.map((g) => groupCard(g, byGroup[g.id], profiles)).join('')}<div class="divider"></div>` : ''}
    <h3 class="section-label">Explore communities</h3>
    ${discover.map((g) => groupCard(g, byGroup[g.id], profiles)).join('') || emptyHtml('No public groups yet', 'Start one!')}`;
};
function groupCard(g, hostIds, profiles) {
  const hosts = (hostIds || []).slice(0, 4).map((uid) => profiles[uid]).filter(Boolean);
  return `<div class="group-card" onclick="go('/group/${g.id}')">
    <div class="top">
      <div class="group-avatar">${g.avatar_url ? `<img src="${escapeHtml(g.avatar_url)}">` : initials(g.name)}</div>
      <div style="flex:1">
        <div class="group-name-row"><span style="font-weight:700">${escapeHtml(g.name)}</span>${g.verified ? ' ✓' : ''}${g.privacy !== 'public' ? `<span class="lock-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg></span>` : ''}</div>
        <div class="muted">${g.host_count} host${g.host_count === 1 ? '' : 's'} · ${g.member_count} members</div>
      </div>
    </div>
    ${g.description ? `<p class="muted" style="margin-top:8px">${escapeHtml(g.description)}</p>` : ''}
    <div class="host-stack">
      ${hosts.length ? `<div class="avatars">${hosts.map((h) => avatarHtml(h.avatar_url, h.display_name, 'sm')).join('')}</div>` : ''}
      <span class="count-pill">${g.member_count}</span>
    </div>
  </div>`;
}
RENDERERS['create-group'] = async (el) => {
  if (!requireAuth()) return;
  el.innerHTML = `<h2 style="margin-bottom:14px">Create a Group</h2>
    <div style="text-align:center;margin-bottom:16px">
      <label for="cg-avatar-file" style="cursor:pointer;display:inline-block">
        <div id="cg-avatar-preview" class="group-avatar" style="width:72px;height:72px;font-size:26px;margin:0 auto">+</div>
      </label>
      <input type="file" id="cg-avatar-file" accept="image/*" style="display:none" onchange="previewGroupAvatar()">
      <input type="hidden" id="cg-avatar-url" value="">
      <p class="muted" style="margin-top:6px">Add a group photo</p>
    </div>
    <label>Name</label><input id="cg-name">
    <label>Category</label><input id="cg-category" value="General Football">
    <label>Description</label><textarea id="cg-desc" rows="3"></textarea>
    <label>Privacy</label><select id="cg-privacy"><option value="public">Public</option><option value="private">Private</option></select>
    <button class="btn" id="cg-submit-btn" onclick="createGroup()">Create group</button>`;
};
let groupAvatarFile = null;
function previewGroupAvatar() {
  groupAvatarFile = document.getElementById('cg-avatar-file').files[0] || null;
  if (!groupAvatarFile) return;
  const url = URL.createObjectURL(groupAvatarFile);
  document.getElementById('cg-avatar-preview').innerHTML = `<img src="${url}" style="width:100%;height:100%;object-fit:cover">`;
}
async function createGroup() {
  const name = document.getElementById('cg-name').value.trim();
  if (!name || name.length < 2) return toast('Name must be at least 2 characters.');
  const btn = document.getElementById('cg-submit-btn');
  btn.disabled = true; btn.textContent = 'Creating...';
  try {
    let avatarUrl = null;
    if (groupAvatarFile) avatarUrl = await uploadToStorage('avatars', groupAvatarFile);
    const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '').slice(0, 39) + '-' + Math.random().toString(36).slice(2, 6);
    const { data, error } = await sb.rpc('create_group', {
      p_name: name, p_slug: slug,
      p_description: document.getElementById('cg-desc').value.trim(),
      p_category: document.getElementById('cg-category').value.trim() || 'General Football',
      p_privacy: document.getElementById('cg-privacy').value,
      p_avatar_url: avatarUrl,
      p_display_name: CURRENT_PROFILE?.display_name || 'Host',
    });
    if (error) throw error;
    groupAvatarFile = null;
    toast('Group created');
    go('/group/' + data.id);
  } catch (e) { toast(e.message || 'Could not create group'); btn.disabled = false; btn.textContent = 'Create group'; }
}
const REACTION_EMOJIS = ['👍', '❤️', '😂', '🔥', '👏', '⚽'];
RENDERERS.group = async (el, id) => {
  const { data: group } = await sb.from('groups').select('*').eq('id', id).single();
  if (!group) { el.innerHTML = emptyHtml('Group not found', ''); return; }
  let myMembership = null;
  if (CURRENT_USER) { const { data } = await sb.from('group_members').select('*').eq('group_id', id).eq('user_id', CURRENT_USER.id).maybeSingle(); myMembership = data; }
  const { data: messages } = await sb.from('group_messages').select('*').eq('group_id', id).is('deleted_at', null).order('created_at', { ascending: false }).limit(60);
  const { data: pins } = await sb.from('group_pins').select('message_id').eq('group_id', id);
  const pinnedIds = new Set((pins || []).map((p) => p.message_id).filter(Boolean));
  const msgIds = (messages || []).map((m) => m.id);
  const { data: reactions } = msgIds.length ? await sb.from('group_message_reactions').select('*').in('message_id', msgIds) : { data: [] };
  const reactionsByMsg = {};
  (reactions || []).forEach((r) => { (reactionsByMsg[r.message_id] = reactionsByMsg[r.message_id] || []).push(r); });
  const profiles = await fetchProfilesMap((messages || []).map((m) => m.sender_id));
  const canAdmin = myMembership && ['owner', 'host', 'moderator'].includes(myMembership.role);
  const canInvite = myMembership && (canAdmin || group.allow_member_invites);
  const render = (list) => list.slice().sort((a, b) => (pinnedIds.has(b.id) - pinnedIds.has(a.id)) || new Date(b.created_at) - new Date(a.created_at)).reverse()
    .map((m) => groupPostHtml(m, profiles[m.sender_id] || { display_name: m.sender_name }, reactionsByMsg[m.id] || [], pinnedIds.has(m.id))).join('') || emptyHtml('No posts yet', '');
  const generalMsgs = (messages || []).filter((m) => m.channel !== 'host');
  const adminMsgs = (messages || []).filter((m) => m.channel === 'host');
  el.innerHTML = `<div class="group-header-banner">
      <div class="row between">
        <div class="group-avatar">${group.avatar_url ? `<img src="${escapeHtml(group.avatar_url)}">` : initials(group.name)}</div>
        ${canInvite ? `<button class="btn-sm secondary" onclick="generateInvite('${id}')"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" style="vertical-align:-2px;margin-right:4px"><path d="M16 3.5a4 4 0 0 1 0 8M8 12.5a4 4 0 0 1 0-8m0 8l8-8"/></svg>Invite</button>` : ''}
      </div>
      <div class="group-name-row"><h2>${escapeHtml(group.name)}</h2>${group.verified ? ' ✓' : ''}${group.privacy !== 'public' ? `<span class="lock-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg> ${group.privacy}</span>` : ''}</div>
      <p class="muted">${escapeHtml(group.description || '')}</p>
      <div class="stat-strip"><div class="stat"><b>${group.host_count}</b><span>hosts</span></div><div class="stat"><b>${group.member_count}</b><span>members</span></div><div class="stat"><b>${group.message_count}</b><span>posts</span></div></div>
      <div class="row between" style="margin-top:12px">
        ${myMembership ? '' : `<button class="btn" onclick="joinGroup('${id}', ${group.join_approval})">${group.join_approval ? 'Request to join' : 'Join group'}</button>`}
        ${canAdmin ? `<button class="btn-sm secondary" onclick="go('/group-admin/${id}')">Manage</button>` : ''}
      </div>
    </div>
    ${myMembership ? `<div class="tabs" id="group-channel-tabs">
        <div class="tab active" onclick="switchGroupChannel(this, 0)">General</div>
        <div class="tab" onclick="switchGroupChannel(this, 1)">Admin chat${!canAdmin ? ' (view only)' : ''}</div>
      </div>
      <div class="group-channel-scroll" id="group-channel-scroll">
        <div class="group-channel-panel">
          <div class="card"><textarea id="gm-input-member" placeholder="Post to the group..." rows="2"></textarea><button class="btn btn-sm" onclick="sendGroupMessage('${id}', 'member')">Post</button></div>
          <div>${render(generalMsgs)}</div>
        </div>
        <div class="group-channel-panel">
          ${canAdmin ? `<div class="card"><textarea id="gm-input-host" placeholder="Post to admins/moderators..." rows="2"></textarea><button class="btn btn-sm" onclick="sendGroupMessage('${id}', 'host')">Post</button></div>` : `<p class="muted" style="margin-bottom:10px">Only admins and moderators can post here — everyone in the group can read it.</p>`}
          <div>${render(adminMsgs)}</div>
        </div>
      </div>` : emptyHtml('Join to see posts', '')}`;
};
function switchGroupChannel(tabEl, index) {
  document.querySelectorAll('#group-channel-tabs .tab').forEach((t) => t.classList.remove('active'));
  tabEl.classList.add('active');
  const scroll = document.getElementById('group-channel-scroll');
  scroll.scrollTo({ left: scroll.clientWidth * index, behavior: 'smooth' });
}
async function generateInvite(groupId) {
  if (!requireAuth()) return;
  try {
    const { data: code, error } = await sb.rpc('create_group_invite', { p_group_id: groupId });
    if (error) throw error;
    const link = `${location.origin}${location.pathname}#/join/${code}`;
    if (navigator.clipboard) { await navigator.clipboard.writeText(link); toast('Invite link copied: ' + code); }
    else toast('Invite code: ' + code);
  } catch (e) { toast(e.message || 'Could not create invite'); }
}
function groupPostHtml(m, profile, msgReactions, isPinned) {
  const counts = {};
  msgReactions.forEach((r) => { counts[r.emoji] = counts[r.emoji] || { n: 0, mine: false }; counts[r.emoji].n++; if (r.user_id === CURRENT_USER?.id) counts[r.emoji].mine = true; });
  return `<div class="post-card ${isPinned ? 'pinned' : ''}">
    ${isPinned ? `<div class="pin-flag"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5M8 3h8l-1 6 3 3v2H6v-2l3-3-1-6z"/></svg> Pinned</div>` : ''}
    ${authorLine(profile, m.created_at)}
    <p style="margin-top:6px">${escapeHtml(m.content)}</p>
    <div class="reaction-row" id="reactions-${m.id}">
      ${Object.entries(counts).map(([emoji, c]) => `<span class="reaction-pill ${c.mine ? 'mine' : ''}" onclick="toggleReaction('${m.id}','${emoji}',this)">${emoji} ${c.n}</span>`).join('')}
      <span class="reaction-add" onclick="openEmojiPicker('${m.id}', this)">+ react</span>
    </div>
  </div>`;
}
let openPicker = null;
function openEmojiPicker(msgId, addEl) {
  if (openPicker) { openPicker.remove(); openPicker = null; }
  const picker = document.createElement('div');
  picker.className = 'emoji-picker';
  picker.innerHTML = REACTION_EMOJIS.map((e) => `<span onclick="toggleReaction('${msgId}','${e}',null);this.parentElement.remove()">${e}</span>`).join('');
  addEl.parentElement.appendChild(picker);
  openPicker = picker;
}
async function toggleReaction(msgId, emoji, pillEl) {
  if (!requireAuth()) return;
  const isMine = pillEl && pillEl.classList.contains('mine');
  if (isMine) await sb.from('group_message_reactions').delete().eq('message_id', msgId).eq('user_id', CURRENT_USER.id).eq('emoji', emoji);
  else await sb.from('group_message_reactions').insert({ message_id: msgId, user_id: CURRENT_USER.id, emoji });
  router();
}
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
async function sendGroupMessage(groupId, channel) {
  const content = document.getElementById('gm-input-' + channel).value.trim();
  if (!content) return;
  const { error } = await sb.from('group_messages').insert({ group_id: groupId, sender_id: CURRENT_USER.id, sender_name: CURRENT_PROFILE?.display_name || 'Member', content, channel });
  if (error) return toast(error.message);
  router();
}
RENDERERS['group-admin'] = async (el, id) => {
  const { data: group } = await sb.from('groups').select('*').eq('id', id).single();
  const { data: myRow } = await sb.from('group_members').select('role').eq('group_id', id).eq('user_id', CURRENT_USER.id).maybeSingle();
  const isOwner = myRow?.role === 'owner';
  const { data: requests } = await sb.from('group_join_requests').select('*').eq('group_id', id).eq('status', 'pending');
  const { data: members } = await sb.from('group_members').select('*').eq('group_id', id).order('joined_at');
  const profiles = await fetchProfilesMap([...(requests || []).map((r) => r.user_id), ...(members || []).map((m) => m.user_id)]);
  el.innerHTML = `<h2 style="margin-bottom:14px">Manage Group</h2>
    ${isOwner ? `<div style="text-align:center;margin-bottom:16px">
      <label for="ga-avatar-file" style="cursor:pointer;display:inline-block">
        <div id="ga-avatar-preview" class="group-avatar" style="width:72px;height:72px;font-size:26px;margin:0 auto">${group?.avatar_url ? `<img src="${escapeHtml(group.avatar_url)}" style="width:100%;height:100%;object-fit:cover">` : initials(group?.name || '')}</div>
      </label>
      <input type="file" id="ga-avatar-file" accept="image/*" style="display:none" onchange="changeGroupAvatar('${id}')">
      <p class="muted" style="margin-top:6px">Tap to change group photo</p>
    </div>` : ''}
    <h3 style="margin-bottom:8px">Join requests (${(requests || []).length})</h3>
    ${(requests || []).map((r) => `<div class="card row between"><span>${escapeHtml(profiles[r.user_id]?.display_name || 'Member')}</span>
      <div class="row"><button class="btn-sm" onclick="reviewJoinRequest('${r.id}','approved','${id}','${r.user_id}')">Approve</button><button class="btn-sm secondary" onclick="reviewJoinRequest('${r.id}','rejected','${id}','${r.user_id}')">Reject</button></div>
    </div>`).join('') || `<p class="muted" style="margin-bottom:14px">No pending requests.</p>`}
    <h3 style="margin:14px 0 8px">Members (${(members || []).length})</h3>
    ${(members || []).map((m) => `<div class="card row between"><span>${escapeHtml(profiles[m.user_id]?.display_name || m.display_name)}</span><span class="pill">${m.role}</span></div>`).join('')}`;
};
async function changeGroupAvatar(groupId) {
  const file = document.getElementById('ga-avatar-file').files[0];
  if (!file) return;
  document.getElementById('ga-avatar-preview').innerHTML = `<div class="spinner" style="margin:22px auto"></div>`;
  try {
    const url = await uploadToStorage('avatars', file);
    const { error } = await sb.from('groups').update({ avatar_url: url }).eq('id', groupId);
    if (error) throw error;
    toast('Group photo updated');
    router();
  } catch (e) { toast(e.message || 'Upload failed'); }
}
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
let REELS_FEED_MODE = 'recommended';
let REELS_DATA = [];
let REELS_VIEW_STARTS = new Map();
const REEL_ICON = {
  comment: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 11.5a7.5 7.5 0 0 1-7.5 7.5H5l-1-4v-3.5A7.5 7.5 0 0 1 11.5 4h1A7.5 7.5 0 0 1 20 11.5Z"/></svg>',
  share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 15V3m-4 4 4-4 4 4"/><path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7"/></svg>',
  save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 4.5A1.5 1.5 0 0 1 7.5 3h9A1.5 1.5 0 0 1 18 4.5V21l-6-4-6 4Z"/></svg>',
  more: '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><circle cx="5" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="19" cy="12" r="1.6"/></svg>'
};
RENDERERS.reels = async (el) => {
  el.innerHTML = `<div class="reels-head"><div><p class="eyebrow">FUSKAMO / WATCH</p><h2>Reels</h2><p class="muted">Short clips from the football community.</p></div><label class="btn reels-upload" for="reel-file">Post a reel</label></div>
    <div class="reels-feed-tabs" role="tablist" aria-label="Reel feed">
      <button type="button" role="tab" aria-selected="${REELS_FEED_MODE === 'recommended'}" class="${REELS_FEED_MODE === 'recommended' ? 'active' : ''}" onclick="setReelsFeed('recommended')">For you</button>
      <button type="button" role="tab" aria-selected="${REELS_FEED_MODE === 'latest'}" class="${REELS_FEED_MODE === 'latest' ? 'active' : ''}" onclick="setReelsFeed('latest')">Latest</button>
    </div>
    <p class="reels-ranking-note">${REELS_FEED_MODE === 'recommended' ? 'Recommended from recent activity, meaningful engagement and watch completion. Recommendations may vary as people interact.' : 'Newest public reels first.'}</p>
    <div id="reels-feed-content" class="reels-loading"><div class="spinner"></div><p>Loading reels…</p></div>
    <input type="file" id="reel-file" accept="video/*" style="display:none" onchange="uploadNewReel()">`;
  await loadReelsInto(el.querySelector('#reels-feed-content'));
};
async function setReelsFeed(mode) {
  REELS_FEED_MODE = mode;
  const el = document.getElementById('view-reels');
  if (!el) return;
  const tabs = el.querySelectorAll('.reels-feed-tabs button');
  tabs.forEach((b) => { const active = (mode === 'recommended' ? b.textContent.trim() === 'For you' : b.textContent.trim() === 'Latest'); b.classList.toggle('active', active); b.setAttribute('aria-selected', String(active)); });
  const note = el.querySelector('.reels-ranking-note');
  if (note) note.textContent = mode === 'recommended' ? 'Recommended from recent activity, meaningful engagement and watch completion. Recommendations may vary as people interact.' : 'Newest public reels first.';
  const content = el.querySelector('#reels-feed-content');
  if (content) { content.innerHTML = '<div class="reels-loading"><div class="spinner"></div><p>Loading reels…</p></div>'; await loadReelsInto(content); }
}
async function loadReelsInto(content) {
  let reels = [];
  if (REELS_FEED_MODE === 'recommended') {
    const { data, error } = await sb.rpc('get_social_reels', { p_limit: 30 });
    if (!error) reels = data || [];
    else console.warn('Recommended reels RPC unavailable; showing newest public reels.', error.message);
  }
  if (REELS_FEED_MODE === 'latest' || !reels.length) {
    const { data, error } = await sb.from('social_reels').select('*').eq('visibility', 'public').eq('status', 'published').order('created_at', { ascending: false }).limit(30);
    if (error) { content.innerHTML = emptyHtml('Reels could not load', 'Check your connection and try again.'); return; }
    reels = data || [];
  }
  REELS_DATA = reels;
  const profiles = await fetchProfilesMap(reels.map((r) => r.author_id));
  const liked = await myLikedSet('social_reel_likes', 'reel_id', reels.map((r) => r.id));
  if (!reels.length) { content.innerHTML = `<div class="reels-empty-upload">${emptyHtml('No reels yet', 'Be the first to upload a clip from your football life.')}</div>`; return; }
  content.innerHTML = `<div class="reels-scroll" id="reels-scroll">
    ${reels.map((r, i) => {
      const author = profiles[r.author_id] || {};
      const name = escapeHtml(author.display_name || author.username || 'FUSKAMO member');
      const handle = author.username ? '@' + escapeHtml(author.username) : '';
      const created = r.created_at ? timeAgo(r.created_at) : '';
      return `<article class="reel-slide" data-index="${i}" data-reel-id="${escapeHtml(r.id)}">
        <video src="${escapeHtml(r.video_url)}" ${r.thumbnail_url ? `poster="${escapeHtml(r.thumbnail_url)}"` : ''} loop muted playsinline preload="${i === 0 ? 'auto' : 'metadata'}" aria-label="Reel by ${name}" onclick="toggleReelMute(this)"></video>
        <div class="reel-top-controls"><span class="reel-sound-label">Tap video for sound</span><button class="reel-more" type="button" onclick="openReelFeedback('${r.id}')" aria-label="More reel options">${REEL_ICON.more}</button></div>
        <div class="mute-hint" id="mute-hint-${i}">Sound ${'off'}</div>
        <div class="reel-overlay">
          <div class="meta">
            <div class="reel-author">${avatarHtml(author.avatar_url, author.display_name || author.username || 'Member', 'sm')}<div><strong>${name}</strong><small>${handle ? handle + (created ? ' · ' : '') : ''}${escapeHtml(created)}</small></div></div>
            <p>${escapeHtml(r.caption || '')}</p>
          </div>
          <div class="reel-actions">
            <button type="button" class="engage-btn ${liked.has(r.id) ? 'liked' : ''}" onclick="toggleReelLike('${r.id}', this)" data-liked="${liked.has(r.id)}" aria-label="${liked.has(r.id) ? 'Unlike reel' : 'Like reel'}">${HEART_SVG(liked.has(r.id))}<span class="cnt">${Number(r.like_count || 0)}</span></button>
            <button type="button" class="engage-btn" onclick="openReelComments('${r.id}')" aria-label="Open comments">${REEL_ICON.comment}<span class="cnt">${Number(r.comment_count || 0)}</span></button>
            <button type="button" class="engage-btn" onclick="shareReel('${r.id}')" aria-label="Share reel">${REEL_ICON.share}<span class="cnt">Share</span></button>
            <button type="button" class="engage-btn" onclick="saveReel('${r.id}', this)" aria-label="Save reel">${REEL_ICON.save}<span class="cnt">Save</span></button>
          </div>
        </div>
      </article>`;
    }).join('')}
  </div>`;
  initReelsAutoplay();
}
function initReelsAutoplay() {
  const videos = [...document.querySelectorAll('#reels-scroll .reel-slide video')];
  if (!videos.length) return;
  if (!('IntersectionObserver' in window)) { videos[0].play().catch(() => {}); return; }
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      const video = entry.target;
      const slide = video.closest('.reel-slide');
      const reelId = slide?.dataset.reelId;
      if (entry.isIntersecting && entry.intersectionRatio > .65) {
        video.play().catch(() => {});
        if (reelId && !REELS_VIEW_STARTS.has(reelId)) REELS_VIEW_STARTS.set(reelId, { started: Date.now(), completed: false, rewatch: 0 });
      } else {
        video.pause();
        if (reelId && REELS_VIEW_STARTS.has(reelId)) {
          const view = REELS_VIEW_STARTS.get(reelId);
          const watchMs = Math.max(0, Date.now() - view.started);
          if (watchMs > 900) sb.rpc('record_reel_view', { p_reel: reelId, p_session: reelSessionId(), p_watch_ms: watchMs, p_completed: watchMs >= (video.duration || Infinity) * 800, p_rewatch: view.rewatch || 0 }).then(() => {}).catch(() => {});
          REELS_VIEW_STARTS.delete(reelId);
        }
      }
    });
  }, { threshold: [0, .25, .65, 1] });
  videos.forEach((v) => observer.observe(v));
  videos[0].play().catch(() => {});
}
function reelSessionId() {
  if (!window.__fuskamoReelSession) window.__fuskamoReelSession = (window.crypto?.randomUUID ? crypto.randomUUID() : 'web-' + Date.now() + '-' + Math.random().toString(36).slice(2));
  return window.__fuskamoReelSession;
}
function toggleReelMute(video) {
  video.muted = !video.muted;
  const slide = video.closest('.reel-slide');
  const hint = slide?.querySelector('.mute-hint');
  if (hint) { hint.textContent = video.muted ? 'Sound off' : 'Sound on'; hint.classList.add('show'); setTimeout(() => hint.classList.remove('show'), 850); }
  const label = slide?.querySelector('.reel-sound-label');
  if (label) label.textContent = video.muted ? 'Tap video for sound' : 'Sound on';
}
async function uploadNewReel() {
  const input = document.getElementById('reel-file');
  if (!requireAuth()) { if (input) input.value = ''; return; }
  const file = input?.files?.[0];
  if (!file) return;
  if (!file.type.startsWith('video/')) { toast('Choose a video file.'); input.value = ''; return; }
  if (file.size > 150 * 1024 * 1024) { toast('Video must be under 150 MB.'); input.value = ''; return; }
  toast('Uploading reel…');
  try {
    const videoUrl = await uploadToStorage('reel-media', file);
    const caption = prompt('Add a caption (optional):', '') || '';
    const { error } = await sb.from('social_reels').insert({ author_id: CURRENT_USER.id, video_url: videoUrl, caption });
    if (error) throw error;
    toast('Reel posted');
    router();
  } catch (e) { toast(e.message || 'Upload failed'); }
  finally { if (input) input.value = ''; }
}
async function toggleReelLike(reelId, button) {
  if (!requireAuth()) return;
  if (button.dataset.busy === 'true') return;
  button.dataset.busy = 'true'; button.disabled = true;
  const wasLiked = button.dataset.liked === 'true';
  const nextLiked = !wasLiked;
  const count = button.querySelector('.cnt');
  const previousCount = Number(count?.textContent || 0);
  button.dataset.liked = String(nextLiked);
  button.classList.toggle('liked', nextLiked);
  button.setAttribute('aria-label', nextLiked ? 'Unlike reel' : 'Like reel');
  if (count) count.textContent = String(Math.max(0, previousCount + (nextLiked ? 1 : -1)));
  try {
    const { data, error } = await sb.rpc('toggle_reel_like', { p_reel: reelId });
    if (error) throw error;
    if (typeof data === 'boolean' && data !== nextLiked) {
      button.dataset.liked = String(data); button.classList.toggle('liked', data);
      if (count) count.textContent = String(Math.max(0, previousCount + (data ? 1 : -1)));
    }
  } catch (e) {
    button.dataset.liked = String(wasLiked); button.classList.toggle('liked', wasLiked);
    if (count) count.textContent = String(previousCount);
    toast(e.message || 'Could not update like');
  } finally { button.disabled = false; button.dataset.busy = 'false'; }
}
async function openReelComments(reelId) {
  const { data: rows, error } = await sb.from('social_reel_comments').select('*').eq('reel_id', reelId).eq('status', 'published').order('created_at', { ascending: true }).limit(200);
  if (error) { toast('Comments are unavailable right now.'); return; }
  const profiles = await fetchProfilesMap((rows || []).map((c) => c.author_id));
  const roots = (rows || []).filter((c) => !c.parent_id);
  const replies = (id) => (rows || []).filter((c) => c.parent_id === id);
  const renderComment = (c, nested = false) => {
    const p = profiles[c.author_id] || {};
    const display = escapeHtml(p.display_name || p.username || 'Member');
    return `<div class="reel-comment ${nested ? 'reply' : ''}"><div class="reel-comment-avatar">${avatarHtml(p.avatar_url, p.display_name || p.username || 'Member', 'sm')}</div><div class="reel-comment-body"><div class="reel-comment-meta"><strong>${display}</strong><small>${escapeHtml(timeAgo(c.created_at))}</small></div><p>${escapeHtml(c.body)}</p>${!nested ? `<button type="button" class="text-action" onclick="toggleReelReplyBox('${c.id}')">Reply</button><div class="reel-reply-box" id="reply-box-${c.id}" hidden><input id="reply-input-${c.id}" maxlength="2000" placeholder="Write a reply" aria-label="Reply to ${display}"><button class="btn" type="button" onclick="submitReelComment('${reelId}','reply-input-${c.id}','${c.id}')">Reply</button></div>${replies(c.id).map((reply) => renderComment(reply, true)).join('')}` : ''}</div></div>`;
  };
  const overlay = document.createElement('div'); overlay.className = 'reel-dialog-backdrop'; overlay.id = 'reel-comments-backdrop';
  overlay.innerHTML = `<section class="reel-comments-sheet" role="dialog" aria-modal="true" aria-labelledby="reel-comments-title"><div class="sheet-grabber"></div><div class="row between"><div><h3 id="reel-comments-title">Comments</h3><p class="muted">${(rows || []).length} comments · keep it respectful</p></div><button class="icon-btn" type="button" onclick="closeReelDialog()" aria-label="Close comments">Close</button></div><div class="reel-comments-list">${roots.map((c) => renderComment(c)).join('') || '<p class="muted" style="padding:16px 0">No comments yet. Start the conversation.</p>'}</div><form class="reel-comment-composer" onsubmit="event.preventDefault();submitReelComment('${reelId}','reel-comment-input')"><input id="reel-comment-input" maxlength="2000" placeholder="${CURRENT_USER ? 'Add a comment…' : 'Sign in to comment'}" aria-label="Add a comment" ${CURRENT_USER ? '' : 'disabled'}><button class="btn" type="submit" ${CURRENT_USER ? '' : 'disabled'}>Post</button></form></section>`;
  overlay.addEventListener('click', (e) => { if (e.target === overlay) closeReelDialog(); });
  document.addEventListener('keydown', reelDialogEscape);
  document.body.appendChild(overlay);
  setTimeout(() => overlay.querySelector('#reel-comment-input')?.focus(), 80);
}
function reelDialogEscape(e) { if (e.key === 'Escape') closeReelDialog(); }
function closeReelDialog() { document.getElementById('reel-comments-backdrop')?.remove(); document.getElementById('reel-feedback-backdrop')?.remove(); document.removeEventListener('keydown', reelDialogEscape); }
function toggleReelReplyBox(id) { const box = document.getElementById('reply-box-' + id); if (box) box.hidden = !box.hidden; }
async function submitReelComment(reelId, inputId, parentId = null) {
  if (!requireAuth()) return;
  const input = document.getElementById(inputId); const body = input?.value?.trim();
  if (!body) { input?.focus(); return; }
  if (body.length > 2000) { toast('Comments must be 2,000 characters or fewer.'); return; }
  const submit = input.closest('form')?.querySelector('button[type="submit"]') || input.parentElement?.querySelector('button');
  if (submit) { submit.disabled = true; submit.dataset.oldText = submit.textContent; submit.textContent = 'Posting…'; }
  try {
    const { error } = await sb.from('social_reel_comments').insert({ reel_id: reelId, author_id: CURRENT_USER.id, parent_id: parentId, body });
    if (error) throw error;
    const { error: countError } = await sb.rpc('refresh_social_reel_counts', { p_reel: reelId });
    if (countError) console.warn('Comment posted; count refresh will catch up.', countError.message);
    toast('Comment posted');
    closeReelDialog();
    const active = document.querySelector(`.reel-slide[data-reel-id="${CSS.escape(reelId)}"] .reel-actions .engage-btn:nth-child(2) .cnt`);
    if (active) active.textContent = String(Number(active.textContent || 0) + 1);
    await openReelComments(reelId);
  } catch (e) { toast(e.message || 'Could not post comment'); }
  finally { if (submit) { submit.disabled = false; submit.textContent = submit.dataset.oldText || 'Post'; } }
}
async function saveReel(reelId, button) {
  if (!requireAuth()) return;
  button.disabled = true;
  try {
    const { data, error } = await sb.rpc('toggle_reel_save', { p_reel: reelId });
    if (error) throw error;
    const saved = Boolean(data);
    button.classList.toggle('saved', saved);
    const cnt = button.querySelector('.cnt'); if (cnt) cnt.textContent = saved ? 'Saved' : 'Save';
    button.setAttribute('aria-label', saved ? 'Unsave reel' : 'Save reel');
    toast(saved ? 'Saved to your collection' : 'Removed from saved reels');
  } catch (e) { toast(e.message || 'Save is unavailable'); }
  finally { button.disabled = false; }
}
async function shareReel(reelId) {
  const reel = REELS_DATA.find((r) => r.id === reelId);
  const url = reel ? new URL(window.location.href) : new URL(window.location.href);
  url.searchParams.set('reel', reelId);
  try {
    if (navigator.share) await navigator.share({ title: 'FUSKAMO reel', text: reel?.caption || 'Watch this reel on FUSKAMO', url: url.toString() });
    else if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(url.toString()); toast('Reel link copied'); }
    else { window.prompt('Copy this reel link', url.toString()); }
    if (CURRENT_USER) { const { error } = await sb.rpc('record_reel_share', { p_reel: reelId, p_channel: 'share_sheet' }); if (error) console.warn('Share could not be recorded', error.message); }
  } catch (e) { if (e.name !== 'AbortError') toast('Could not share reel'); }
}
function openReelFeedback(reelId) {
  closeReelDialog();
  const overlay = document.createElement('div'); overlay.className = 'reel-dialog-backdrop'; overlay.id = 'reel-feedback-backdrop';
  overlay.innerHTML = `<section class="reel-feedback-sheet" role="dialog" aria-modal="true" aria-label="Reel preferences"><div class="row between"><div><h3>Reel preferences</h3><p class="muted">Help shape what appears in your feed.</p></div><button type="button" class="icon-btn" onclick="closeReelDialog()">Close</button></div><button class="reel-feedback-option" onclick="sendReelFeedback('${reelId}','not_interested')"><strong>Not interested</strong><span>Show fewer reels like this.</span></button><button class="reel-feedback-option" onclick="sendReelFeedback('${reelId}','show_more')"><strong>Show me more like this</strong><span>Help improve your recommendations.</span></button><button class="reel-feedback-option" onclick="sendReelFeedback('${reelId}','report')"><strong>Report this reel</strong><span>Flag content that may violate community rules.</span></button></section>`;
  overlay.addEventListener('click', (e) => { if (e.target === overlay) closeReelDialog(); }); document.addEventListener('keydown', reelDialogEscape); document.body.appendChild(overlay);
}
async function sendReelFeedback(reelId, feedback) {
  if (!requireAuth()) return;
  try {
    if (feedback === 'report') {
      const options = ['spam','harassment','impersonation','scam','hate','sexual','violence','copyright','misinformation','other'];
      const choice = window.prompt('Choose a report reason: ' + options.join(', '), 'other');
      const reason = options.includes((choice || '').trim().toLowerCase()) ? choice.trim().toLowerCase() : null;
      if (!reason) { toast('Choose one of the listed report reasons.'); return; }
      const details = window.prompt('Optional details for the review team (up to 2,000 characters):', '') || '';
      const { error } = await sb.from('content_reports').insert({ reporter_id: CURRENT_USER.id, target_type: 'reel', target_id: reelId, reason, details: details.slice(0, 2000) });
      if (error) throw error;
      toast('Report submitted for review');
    } else {
      const { error } = await sb.from('social_reel_feedback').upsert({ reel_id: reelId, user_id: CURRENT_USER.id, feedback });
      if (error) throw error;
      toast(feedback === 'not_interested' ? 'We’ll try to show you fewer reels like this' : 'Thanks — recommendations updated');
    }
    closeReelDialog();
    if (feedback === 'not_interested') { const slide = document.querySelector(`.reel-slide[data-reel-id="${CSS.escape(reelId)}"]`); slide?.remove(); }
  } catch (e) { toast(e.message || 'Could not save this preference'); }
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
  el.innerHTML = `<div class="row between" style="margin-bottom:14px">
      <div class="row">${avatarHtml(p.avatar_url, p.display_name, 'lg')}
        <div><h2>${escapeHtml(p.display_name || 'FUSKAMO Member')}${badgeHtml(p.badge_type, p.verified)}</h2><span class="muted">@${escapeHtml(p.username || 'unset')} · ${p.role}</span></div></div>
      <button class="icon-btn" onclick="openProfileMenu()" aria-label="Menu"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="5" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="12" cy="19" r="1.2"/></svg></button>
    </div>
    <p style="margin-bottom:10px">${escapeHtml(p.bio || '')}</p>
    <div class="row" style="gap:20px;margin-bottom:14px"><span><b>${followers || 0}</b> <span class="muted">followers</span></span><span><b>${following || 0}</b> <span class="muted">following</span></span></div>
    <div class="grid-2" style="margin-bottom:14px">
      <button class="btn secondary" onclick="go('/edit-profile')">Edit profile</button>
      <button class="btn secondary" onclick="go('/analytics')">Analytics</button>
    </div>
    <div id="profile-menu-backdrop" class="menu-backdrop" onclick="closeProfileMenu()"></div>
    <div id="profile-menu-sheet" class="menu-sheet">
      <div class="menu-sheet-handle"></div>
      ${chev('Account settings', "go('/account-settings');closeProfileMenu()")}
      ${chev('Security', "go('/security-settings');closeProfileMenu()")}
      ${chev('New story', "go('/story-settings');closeProfileMenu()")}
      ${chev('Get verified', "go('/verification');closeProfileMenu()")}
      ${chev('My reports', "go('/moderation');closeProfileMenu()")}
      ${chev('Two-factor authentication', "go('/mfa-setup');closeProfileMenu()")}
      <button class="btn danger" style="margin-top:14px" onclick="signOut()">Sign out</button>
    </div>`;
};
function chev(label, onclick) {
  return `<div class="settings-link" onclick="${onclick}"><span>${label}</span><span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l7 7-7 7"/></svg></span></div>`;
}
function openProfileMenu() {
  document.getElementById('profile-menu-backdrop').classList.add('show');
  document.getElementById('profile-menu-sheet').classList.add('show');
}
function closeProfileMenu() {
  document.getElementById('profile-menu-backdrop').classList.remove('show');
  document.getElementById('profile-menu-sheet').classList.remove('show');
}

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
    <div style="text-align:center;margin-bottom:16px">
      <label for="ep-avatar-file" style="cursor:pointer;display:inline-block;position:relative">
        <div id="ep-avatar-preview">${avatarHtml(p.avatar_url, p.display_name, 'lg')}</div>
        <div style="position:absolute;bottom:0;right:0;background:var(--green);border-radius:50%;width:26px;height:26px;display:flex;align-items:center;justify-content:center;border:2px solid var(--black)"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="var(--black)" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M21 16l-5-4-4 3-3-2-6 5"/></svg></div>
      </label>
      <input type="file" id="ep-avatar-file" accept="image/*" style="display:none" onchange="uploadAvatarNow()">
      <p class="muted" style="margin-top:6px">Tap to change photo</p>
    </div>
    <label>Display name</label><input id="ep-name" value="${escapeHtml(p.display_name || '')}">
    <label>Username</label><input id="ep-username" value="${escapeHtml(p.username || '')}" oninput="checkUsernameAvailable()" placeholder="lowercase, starts with a letter">
    <p class="muted" id="ep-username-status" style="margin:-6px 0 10px"></p>
    <label>Bio</label><textarea id="ep-bio" rows="3">${escapeHtml(p.bio || '')}</textarea>
    <input type="hidden" id="ep-avatar" value="${escapeHtml(p.avatar_url || '')}">
    <label>Website</label><input id="ep-website" value="${escapeHtml(p.website || '')}">
    <label>Instagram</label><input id="ep-instagram" value="${escapeHtml(p.instagram || '')}">
    <label>Who can message you</label><select id="ep-msgreq"><option value="everyone" ${p.message_requests === 'everyone' ? 'selected' : ''}>Everyone</option><option value="followers" ${p.message_requests === 'followers' ? 'selected' : ''}>Followers</option><option value="nobody" ${p.message_requests === 'nobody' ? 'selected' : ''}>Nobody</option></select>
    <button class="btn" onclick="saveProfile()">Save</button>`;
};
async function uploadAvatarNow() {
  if (!requireAuth()) return;
  const file = document.getElementById('ep-avatar-file').files[0];
  if (!file) return;
  document.getElementById('ep-avatar-preview').innerHTML = `<div class="avatar lg"><div class="spinner" style="margin:22px auto"></div></div>`;
  try {
    const url = await uploadToStorage('avatars', file);
    document.getElementById('ep-avatar').value = url;
    document.getElementById('ep-avatar-preview').innerHTML = `<div class="avatar lg"><img src="${url}"></div>`;
  } catch (e) { toast(e.message || 'Upload failed'); }
}
let usernameCheckTimer;
function checkUsernameAvailable() {
  clearTimeout(usernameCheckTimer);
  const raw = document.getElementById('ep-username').value.trim().toLowerCase();
  const status = document.getElementById('ep-username-status');
  if (!raw) { status.textContent = ''; return; }
  if (!/^[a-z][a-z0-9_]{2,19}$/.test(raw)) {
    status.style.color = 'var(--red)';
    status.textContent = 'Lowercase letters/numbers/underscore, must start with a letter, 3-20 characters.';
    return;
  }
  status.style.color = 'var(--sub)';
  status.textContent = 'Checking availability...';
  usernameCheckTimer = setTimeout(async () => {
    const { data } = await sb.from('profiles').select('user_id').ilike('username', raw).maybeSingle();
    if (data && data.user_id !== CURRENT_USER.id) { status.style.color = 'var(--red)'; status.textContent = 'That username is taken.'; }
    else { status.style.color = 'var(--green)'; status.textContent = 'Available.'; }
  }, 400);
}
async function saveProfile() {
  const payload = {
    display_name: document.getElementById('ep-name').value.trim(),
    username: document.getElementById('ep-username').value.trim().toLowerCase() || null,
    bio: document.getElementById('ep-bio').value.trim(),
    avatar_url: document.getElementById('ep-avatar').value.trim() || null,
    website: document.getElementById('ep-website').value.trim() || null,
    instagram: document.getElementById('ep-instagram').value.trim() || null,
    message_requests: document.getElementById('ep-msgreq').value,
    updated_at: new Date().toISOString(),
  };
  const { error } = await sb.from('profiles').update(payload).eq('user_id', CURRENT_USER.id);
  if (error) {
    if (error.code === '23505') return toast('That username is already taken.');
    if (error.code === '23514') return toast('Username must be lowercase, start with a letter, 3-20 characters.');
    return toast(error.message);
  }
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
    <label for="st-file" class="btn secondary" style="cursor:pointer;display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:10px">
      <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M21 16l-5-4-4 3-3-2-6 5"/></svg> Choose photo or video
    </label>
    <input type="file" id="st-file" accept="image/*,video/*" style="display:none" onchange="previewStoryFile()">
    <div id="st-preview"></div>
    <label>Caption</label><textarea id="st-caption" rows="2"></textarea>
    <label>Visible to</label><select id="st-vis"><option value="followers">Followers</option><option value="public">Everyone</option><option value="close_friends">Close friends</option></select>
    <button class="btn" id="st-submit-btn" onclick="postStory()">Share story</button>`;
};
let storyFile = null;
function previewStoryFile() {
  storyFile = document.getElementById('st-file').files[0] || null;
  const box = document.getElementById('st-preview');
  if (!storyFile) { box.innerHTML = ''; return; }
  const url = URL.createObjectURL(storyFile);
  box.innerHTML = storyFile.type.startsWith('video')
    ? `<video src="${url}" style="width:100%;border-radius:var(--r-sm);max-height:280px;margin-bottom:10px" controls></video>`
    : `<img src="${url}" style="width:100%;border-radius:var(--r-sm);max-height:280px;object-fit:cover;margin-bottom:10px">`;
}
async function postStory() {
  if (!storyFile) return toast('Choose a photo or video first.');
  const btn = document.getElementById('st-submit-btn');
  btn.disabled = true; btn.textContent = 'Uploading...';
  try {
    const mediaUrl = await uploadToStorage('story-media', storyFile);
    const mediaType = storyFile.type.startsWith('video') ? 'external_video' : 'image';
    const { error } = await sb.from('social_stories').insert({ author_id: CURRENT_USER.id, media_url: mediaUrl, media_type: mediaType, caption: document.getElementById('st-caption').value.trim(), visibility: document.getElementById('st-vis').value });
    if (error) throw error;
    storyFile = null;
    toast('Story posted');
    go('/profile');
  } catch (e) { toast(e.message || 'Upload failed'); btn.disabled = false; btn.textContent = 'Share story'; }
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
