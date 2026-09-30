import test from 'node:test';
import assert from 'node:assert/strict';
import * as C from '../public/core.js';

test('CSV quotes, CRLF, BOM', () => {
  assert.deepEqual(C.parseCSV('﻿a,b\r\n"x, y","he said ""hi"""\r\n1,"l1\nl2"\r\n'),
    [['a', 'b'], ['x, y', 'he said "hi"'], ['1', 'l1\nl2']]);
});
test('table pads short rows, sorts numerically with blanks last', () => {
  const t = C.sortTable(C.toTable('n,v\nA,2\nB,10\nC,\nD\n'), 'v', false);
  assert.deepEqual(t.rows.map(r => r[0]), ['B', 'A', 'C', 'D']);
});
test('CSV round trip', () => {
  const t = { columns: ['a'], rows: [['x,"y"']] };
  assert.deepEqual(C.toTable(C.tableToCSV(t)), t);
});
test('statcast split params', () => {
  const p = C.statcastParams({ role: 'batter', playerID: 660271, seasons: [2025], pitcherThrows: 'L' });
  assert.equal(p.pitcher_throws, 'L'); assert.equal(p.hfSea, '2025|'); assert.equal(p['batters_lookup[]'], '660271');
  assert.equal(C.statcastParams({ role: 'pitcher', playerID: 1 })['pitchers_lookup[]'], '1');
});
test('leaderboard params', () => {
  const oaa = C.LEADERBOARDS.find(l => l.path === 'outs_above_average');
  const p = C.leaderboardParams(oaa, 2025);
  assert.equal(p.startYear, '2025'); assert.equal(p.endYear, '2025');
  const xs = C.LEADERBOARDS.find(l => l.path === 'expected_statistics');
  assert.equal(C.leaderboardParams(xs, 2025, 'pitcher').type, 'pitcher');
});
test('player search normalisation tolerates shapes', () => {
  assert.deepEqual(C.normalizePlayers([{ id: 1, name: 'A', pos: 'SS', team: 'X' }, { player_id: 2, player_name: 'B' }, { name: 'no id' }]),
    [{ id: 1, name: 'A', meta: 'SS · X' }, { id: 2, name: 'B', meta: '' }]);
});
