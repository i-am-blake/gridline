// Gridline offline support: the game itself is cached so it opens without a connection;
// fonts and the music library are cached the first time they load.
const CACHE = 'gridline-v2';
const CORE = ['./', 'index.html', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/apple-touch-icon.png'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // never cache stats or the leaderboard
  if (/goatcounter|supabase|gc\.zgo\.at/.test(url.hostname)) return;
  // songs stream straight from the network (phones need ranged requests for audio, which caches handle badly)
  if (url.pathname.endsWith('.mp3') || req.headers.has('range')) return;
  // the game page: fresh when online, cached when offline
  if (req.mode === 'navigate' || url.pathname.endsWith('/index.html')){
    e.respondWith(fetch(req).then(r => { const c = r.clone(); caches.open(CACHE).then(k => k.put('index.html', c)); return r; }).catch(() => caches.match('index.html')));
    return;
  }
  // everything else: cache first, then network (and keep a copy)
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => { if (r.ok || r.type === 'opaque'){ const c = r.clone(); caches.open(CACHE).then(k => k.put(req, c)); } return r; })));
});
