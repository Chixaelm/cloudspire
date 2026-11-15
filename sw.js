// Cloudspire offline cache. The page and its own files are fetched fresh when online (falling back to the cache when the
// network is down or slow); three.js is versioned on the CDN, so it is stored once and served from the cache after that.
const C = 'cloudspire-v2', T3 = 'https://cdn.jsdelivr.net/npm/three@0.160.0/';
const CDN = ['build/three.module.js', ...['postprocessing/EffectComposer.js', 'postprocessing/RenderPass.js', 'postprocessing/Pass.js', 'postprocessing/ShaderPass.js', 'postprocessing/MaskPass.js',
  'postprocessing/UnrealBloomPass.js', 'postprocessing/OutputPass.js', 'shaders/CopyShader.js', 'shaders/LuminosityHighPassShader.js', 'shaders/OutputShader.js', 'utils/BufferGeometryUtils.js'].map(f => 'examples/jsm/' + f)].map(f => T3 + f);
const OWN = ['./', 'edge.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'icon-180.png'];
self.addEventListener('install', e => { self.skipWaiting();
  e.waitUntil(caches.open(C).then(c => Promise.all([...OWN, ...CDN].map(u => c.match(u).then(m => m || c.add(u)).catch(() => { }))))); });
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const r = e.request; if (r.method !== 'GET' || !r.url.startsWith('http')) return;
  const put = res => { if (res.ok) { const cl = res.clone(); e.waitUntil(caches.open(C).then(c => c.put(r, cl)).catch(() => { })); } return res; };
  const cached = () => caches.match(r, { ignoreSearch: r.mode === 'navigate' }).then(m => m || (r.mode === 'navigate' ? caches.match('./') : undefined));
  if (new URL(r.url).origin !== location.origin) { e.respondWith(caches.match(r).then(m => m || fetch(r).then(put))); return; }
  // same origin: network first, but do not leave a phone on a weak signal staring at a blank screen
  e.respondWith(new Promise((done, fail) => {
    let settled = false; const use = x => { if (!settled && x) { settled = true; done(x); } };
    const t = setTimeout(() => cached().then(use), 3500);
    fetch(r).then(put).then(res => { clearTimeout(t); use(res); }, () => { clearTimeout(t); cached().then(m => m ? use(m) : settled || fail(new TypeError('offline'))); });
  }));
});
