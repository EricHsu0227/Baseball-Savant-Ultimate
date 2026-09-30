// Zero-dependency server: serves the SPA and proxies Savant (which sends no CORS headers).
const http = require('http');
const fs = require('fs');
const path = require('path');

const BASE = process.env.SAVANT_BASE || 'https://baseballsavant.mlb.com';
const PORT = Number(process.env.PORT || 3000);
const TTL_MS = 5 * 60 * 1000;
const ALLOWED = ['leaderboard/', 'statcast_search/', 'player/search-all', 'savant-player/'];
const PUBLIC = path.join(__dirname, 'public');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };
const cache = new Map();

async function proxy(req, res, url) {
  const upstreamPath = url.pathname.replace(/^\/savant\//, '');
  if (upstreamPath.includes('..') || !ALLOWED.some(p => upstreamPath.startsWith(p))) {
    res.writeHead(403); return res.end('path not allowed');
  }
  const target = `${BASE}/${upstreamPath}${url.search}`;
  const hit = cache.get(target);
  if (hit && Date.now() - hit.t < TTL_MS) return send(res, hit.status, hit.type, hit.body, 'HIT');
  try {
    const r = await fetch(target, { headers: { 'User-Agent': 'savant-ultimate/0.1', Accept: '*/*' }, signal: AbortSignal.timeout(60000) });
    const body = Buffer.from(await r.arrayBuffer());
    const type = r.headers.get('content-type') || 'text/plain';
    if (r.ok) cache.set(target, { t: Date.now(), status: r.status, type, body });
    send(res, r.status, type, body, 'MISS');
  } catch (e) {
    send(res, 502, 'text/plain', Buffer.from(`Upstream error: ${e.message}`), 'ERR');
  }
}
function send(res, status, type, body, cacheState) {
  res.writeHead(status, { 'Content-Type': type, 'X-Cache': cacheState });
  res.end(body);
}
function serveStatic(res, url) {
  const rel = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname).replace(/^\/+/, '');
  const file = path.join(PUBLIC, rel);
  if (!file.startsWith(PUBLIC + path.sep)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method !== 'GET') { res.writeHead(405); return res.end(); }
  return url.pathname.startsWith('/savant/') ? proxy(req, res, url) : serveStatic(res, url);
});
if (require.main === module) server.listen(PORT, () => console.log(`Savant Ultimate on http://localhost:${PORT}  (upstream: ${BASE})`));
module.exports = server;
