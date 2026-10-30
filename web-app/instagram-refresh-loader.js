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
    const [styles, scriptText] = await Promise.all([
      unpack(['instagram-refresh-css-01.b64','instagram-refresh-css-02.b64','instagram-refresh-css-03.b64','instagram-refresh-css-04.b64','instagram-refresh-css-05.b64']),
      unpack(['instagram-refresh-js-01.b64','instagram-refresh-js-02.b64','instagram-refresh-js-03.b64','instagram-refresh-js-04.b64','instagram-refresh-js-05.b64','instagram-refresh-js-06.b64','instagram-refresh-js-07.b64','instagram-refresh-js-08.b64','instagram-refresh-js-09.b64','instagram-refresh-js-10.b64','instagram-refresh-js-11.b64','instagram-refresh-js-12.b64'])
    ]);
    const style = document.createElement('style');
    style.id = 'fuskamo-social-refresh-styles';
    style.textContent = styles;
    document.head.appendChild(style);
    const script = document.createElement('script');
    script.id = 'fuskamo-social-refresh-runtime';
    script.textContent = scriptText;
    document.body.appendChild(script);
  } catch (error) {
    console.error('[FUSKAMO] Social UI refresh could not be loaded:', error);
  }
})();