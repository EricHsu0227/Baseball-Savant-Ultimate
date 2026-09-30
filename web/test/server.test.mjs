import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';

test('proxy forwards allowed paths, caches, blocks others', async () => {
  let hits = 0, lastUrl = '';
  const fake = http.createServer((req, res) => { hits++; lastUrl = req.url; res.writeHead(200, { 'Content-Type': 'text/csv' }); res.end('player,woba\nA,.400\n'); });
  await new Promise(r => fake.listen(0, r));
  process.env.SAVANT_BASE = `http://127.0.0.1:${fake.address().port}`;
  const server = (await import('../server.js')).default;
  await new Promise(r => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const a = await fetch(`${base}/savant/statcast_search/csv?pitcher_throws=L&hfSea=2025%7C`);
    assert.equal(a.status, 200); assert.equal(a.headers.get('x-cache'), 'MISS');
    assert.equal(await a.text(), 'player,woba\nA,.400\n');
    assert.match(lastUrl, /pitcher_throws=L&hfSea=2025%7C/);
    const b = await fetch(`${base}/savant/statcast_search/csv?pitcher_throws=L&hfSea=2025%7C`);
    assert.equal(b.headers.get('x-cache'), 'HIT'); assert.equal(hits, 1);
    assert.equal((await fetch(`${base}/savant/admin/secret`)).status, 403);
    assert.equal((await fetch(`${base}/savant/leaderboard/../x`)).status, 403);
    assert.equal((await fetch(`${base}/`)).status, 200);
    assert.equal((await fetch(`${base}/..%2fserver.js`)).status, 403);
  } finally { server.close(); fake.close(); }
});
