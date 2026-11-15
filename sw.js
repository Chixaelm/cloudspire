// Cloudspire offline cache: the page is fetched fresh when online, everything else (three.js from the CDN, icons) is served from cache once seen.
const C = 'cloudspire-v1';
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(C).then(c => c.addAll(['./', 'manifest.webmanifest', 'icon-192.png']))); });
self.addEventListener('activate', e => e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const r = e.request; if (r.method !== 'GET' || !r.url.startsWith('http')) return;
  const put = res => { if (res.ok) { const cl = res.clone(); caches.open(C).then(c => c.put(r, cl)); } return res; };
  if (r.mode === 'navigate') e.respondWith(fetch(r).then(put).catch(() => caches.match(r, { ignoreSearch: true }).then(m => m || caches.match('./'))));
  else e.respondWith(caches.match(r).then(m => m || fetch(r).then(put)));
});
