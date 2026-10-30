/* Loads the bundled social UX layer from same-origin compressed text assets. */
(async function loadFuskamoSocialRefresh() {
  const base = document.currentScript.src;
  async function fetchParts(paths) {
    const parts = await Promise.all(paths.map(async (path) => {
      const response = await fetch(new URL(path, base), { cache: 'force-cache' });
      if (!response.ok) throw new Error(`Could not load ${path} (${response.status})`);
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
        el.innerHTML = `<section class="ir-settings-page">
          <div class="ir-page-heading"><p class="ir-kicker">SAFETY & SUPPORT</p><h1>My reports</h1><p>Review the reports you have submitted to FUSKAMO. Report details are visible only to you and authorised moderators.</p></div>
          ${rows.map(r => `<article class="ir-report-card"><div class="ir-report-top"><b>${esc(r.target_type)} report · ${esc(r.reason)}</b><span class="ir-report-status status-${esc(r.status)}">${labels[r.status] || esc(r.status)}</span></div><small>Submitted ${esc(new Date(r.created_at).toLocaleDateString())}</small>${r.details ? `<p>${esc(r.details)}</p>` : ''}${r.resolution ? `<div class="ir-report-resolution"><b>Review update</b><p>${esc(r.resolution)}</p></div>` : ''}</article>`).join('') || '<div class="ir-empty"><div class="ir-empty-icon">✓</div><h3>No reports submitted</h3><p>When you report a post, profile, story or message, its review status will appear here.</p></div>'}
        </section>`;
      };
    `;
    const style = document.createElement('style');
    style.id = 'fuskamo-social-refresh-styles';
    style.textContent = styles;
    document.head.appendChild(style);
    const script = document.createElement('script');
    script.id = 'fuskamo-social-refresh-runtime';
    script.textContent = scriptText;
    document.body.appendChild(script);
    window.__fuskamoSocialRefreshReady = true;
  } catch (error) {
    console.error('[FUSKAMO] Social UI refresh could not be loaded:', error);
  }
})();