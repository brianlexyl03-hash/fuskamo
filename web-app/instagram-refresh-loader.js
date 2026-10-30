/* Loads the refreshed social UI bundle and adds account-owned report tracking. */
(async function loadFuskamoSocialRefresh() {
  const base = document.currentScript.src;
  async function fetchParts(paths) {
    const parts = await Promise.all(paths.map(async (path) => {
      const response = await fetch(new URL(path, base), { cache: 'force-cache' });
      if (!response.ok) throw new Error('Could not load ' + path + ' (' + response.status + ')');
      return (await response.text()).trim();
    }));
    return parts.join('');
  }
  async function unpack(paths) {
    if (!('DecompressionStream' in window)) throw new Error('This browser does not support the FUSKAMO UI bundle format.');
    const encoded = await fetchParts(paths);
    const binary = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
    const stream = new Blob([binary]).stream().pipeThrough(new DecompressionStream('gzip'));
    return new Response(stream).text();
  }
  try {
    const [styles, loadedScriptText] = await Promise.all([
      unpack(['instagram-refresh-css-01.b64','instagram-refresh-css-02.b64','instagram-refresh-css-03.b64','instagram-refresh-css-04.b64','instagram-refresh-css-05.b64']),
      unpack(['instagram-refresh-js-01.b64','instagram-refresh-js-02.b64','instagram-refresh-js-03.b64','instagram-refresh-js-04.b64','instagram-refresh-js-05.b64','instagram-refresh-js-06.b64','instagram-refresh-js-07.b64','instagram-refresh-js-08.b64','instagram-refresh-js-09.b64','instagram-refresh-js-10.b64','instagram-refresh-js-11.b64','instagram-refresh-js-12.b64'])
    ]);
    let scriptText = loadedScriptText;
    scriptText = scriptText.replace("rowLink('Reports and support','Your submitted reports','/moderation','!')", "rowLink('My reports','Track reports you have submitted','/my-reports','!')");
    scriptText = scriptText.replace("rowLink('Your reports','Report history and moderation','/moderation','!')", "rowLink('My reports','Report history and status','/my-reports','!')");
    scriptText = scriptText.replace("const d=settingsRes.data||{};const blocked=", "const d=settingsRes.data||{login_alerts:true,new_device_alerts:true,message_request_filter:true,allow_search_by_email:false,allow_search_by_phone:false};const blocked=");
    scriptText = scriptText.replace("['Followers gained','followers']", "['Followers','followers']");
    scriptText = scriptText.replace('class="ir-media-heart"', 'class="ir-media-heart dbl-heart"');
    scriptText = scriptText.replace('class="ir-action ${isLiked?\'liked\':\'\'}"', 'class="ir-action engage-btn ${isLiked?\'liked\':\'\'}"');
    scriptText = scriptText.replace('<b>${safeCount(post.like_count)} likes</b>', '<b class="ir-like-count" data-count="${safeCount(post.like_count)}">${safeCount(post.like_count)} likes</b>');
    scriptText = scriptText.replace('>${HEART_SVG(isLiked)}</button>', '>${HEART_SVG(isLiked)}<span class="cnt" hidden>${safeCount(post.like_count)}</span></button>');
    scriptText = scriptText.replace("const totals=Object.fromEntries(keys.map(([label,k])=>[k,rows.reduce((sum,r)=>sum+Number(r[k]||0),0)]));", "const totals=Object.fromEntries(keys.map(([label,k])=>[k,k==='followers'?Number(rows.at(-1)?.[k]||0):rows.reduce((sum,r)=>sum+Number(r[k]||0),0)]));");
    scriptText += `
      ROUTES.push('my-reports');
      RENDERERS['my-reports'] = async (el) => {
        if (!requireAuth()) return;
        const { data, error } = await sb.from('content_reports')
          .select('id,target_type,target_id,reason,details,status,resolution,created_at,resolved_at')
          .eq('reporter_id', CURRENT_USER.id).order('created_at', { ascending: false }).limit(50);
        if (error) { el.innerHTML = '<section class="ir-settings-page"><h1>My reports</h1><p class="ir-muted">' + esc(error.message) + '</p></section>'; return; }
        const rows = data || [];
        const labels = { open: 'Submitted', reviewing: 'Under review', resolved: 'Resolved', dismissed: 'Closed' };
        el.innerHTML = '<section class="ir-settings-page">' +
          '<div class="ir-page-heading"><p class="ir-kicker">SAFETY & SUPPORT</p><h1>My reports</h1><p>Review the reports you have submitted to FUSKAMO. Report details are visible only to you and authorised moderators.</p></div>' +
          rows.map(r => '<article class="ir-report-card"><div class="ir-report-top"><b>' + esc(r.target_type) + ' report · ' + esc(r.reason) + '</b><span class="ir-report-status status-' + esc(r.status) + '">' + (labels[r.status] || esc(r.status)) + '</span></div><small>Submitted ' + esc(new Date(r.created_at).toLocaleDateString()) + '</small>' + (r.details ? '<p>' + esc(r.details) + '</p>' : '') + (r.resolution ? '<div class="ir-report-resolution"><b>Review update</b><p>' + esc(r.resolution) + '</p></div>' : '') + '</article>').join('') +
          (rows.length ? '' : '<div class="ir-empty"><div class="ir-empty-icon">✓</div><h3>No reports submitted</h3><p>When you report a post, profile, story or message, its review status will appear here.</p></div>') +
          '</section>';
      };
      window.togglePostLike = async (postId, button) => {
        if (!requireAuth()) return;
        const liked = button.dataset.liked === 'true';
        const query = liked
          ? sb.from('social_post_likes').delete().eq('post_id', postId).eq('user_id', CURRENT_USER.id)
          : sb.from('social_post_likes').insert({ post_id: postId, user_id: CURRENT_USER.id });
        const { error } = await query;
        if (error) { toast(error.message); return; }
        const countNode = button.closest('.ir-post')?.querySelector('.ir-like-count');
        const current = Number(countNode?.dataset.count || button.querySelector('.cnt')?.textContent || 0);
        const next = Math.max(0, current + (liked ? -1 : 1));
        if (countNode) { countNode.dataset.count = String(next); countNode.textContent = next.toLocaleString() + ' likes'; }
        button.dataset.liked = String(!liked);
        button.classList.toggle('liked', !liked);
        button.setAttribute('aria-label', liked ? 'Like' : 'Unlike');
        button.innerHTML = HEART_SVG(!liked) + '<span class="cnt" hidden>' + next + '</span>';
      };
      window.dblTapLike = async (postId, wrapEl) => {
        if (!requireAuth()) return;
        const button = wrapEl.closest('.ir-post')?.querySelector('.engage-btn');
        if (button && button.dataset.liked !== 'true') await window.togglePostLike(postId, button);
        const heart = wrapEl.querySelector('.dbl-heart');
        if (heart) { heart.classList.add('pop'); setTimeout(() => heart.classList.remove('pop'), 700); }
      };
    `;
    const style = document.createElement('style');
    style.id = 'fuskamo-social-refresh-styles';
    style.textContent = styles + '\n.ir-report-card{padding:15px;margin:10px 0;border:1px solid var(--ir-line);border-radius:12px;background:var(--ir-panel)}.ir-report-top{display:flex;justify-content:space-between;align-items:center;gap:10px}.ir-report-top b{font-size:13px;text-transform:capitalize}.ir-report-card small{display:block;margin-top:6px;color:var(--ir-muted);font-size:10px}.ir-report-card p{font-size:12px;line-height:1.5;color:var(--ir-muted)}.ir-report-status{font-size:10px;padding:5px 8px;border-radius:99px;background:#282d2a;color:#c5cfb0;white-space:nowrap}.ir-report-status.status-resolved{background:#203329;color:#9dd8ae}.ir-report-status.status-dismissed{background:#333;color:#bbb}.ir-report-resolution{padding:9px 11px;border-left:2px solid var(--ir-accent);background:#1b201b}.ir-report-resolution b{font-size:11px}.ir-report-resolution p{margin:4px 0 0}';
    document.head.appendChild(style);
    const script = document.createElement('script');
    script.id = 'fuskamo-social-refresh-runtime';
    script.textContent = scriptText;
    document.body.appendChild(script);
    window.__fuskamoSocialRefreshReady = true;
    if (typeof router === 'function') router();
  } catch (error) {
    console.error('[FUSKAMO] Social UI refresh could not be loaded:', error);
  }
})();