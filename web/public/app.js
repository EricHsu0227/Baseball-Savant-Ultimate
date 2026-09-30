import * as C from './core.js';

const $ = (s, el = document) => el.querySelector(s);
const h = (html) => { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstChild; };
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const year = () => Number($('#season').value);
const thisYear = new Date().getFullYear();

const sel = $('#season');
const saved = Number(localStorage.getItem('season')) || thisYear;
for (let y = thisYear; y >= 2015; y--) sel.append(new Option(y, y, false, y === saved));
sel.onchange = () => { localStorage.setItem('season', sel.value); route(); };

async function get(path, params) {
  const r = await fetch(`/savant/${path}?${new URLSearchParams(params)}`);
  const body = await r.text();
  if (!r.ok) throw new Error(`Savant returned HTTP ${r.status}. ${body.slice(0, 120)}`);
  return body;
}
async function getTable(path, params) {
  const body = await get(path, params);
  if (body.trimStart().startsWith('<')) throw new Error('Savant returned HTML, not CSV (endpoint or params may have changed).');
  return C.toTable(body);
}

/** Sortable, filterable table showing EVERY column returned. */
function tableView(table, name = 'savant') {
  let sort = null, asc = false, q = '';
  const root = h(`<div><div class="bar"><input type="search" placeholder="Filter rows…"><button class="ghost">Download CSV</button>
    <span class="muted"></span></div><div class="tablewrap"></div></div>`);
  const wrap = $('.tablewrap', root), info = $('.muted', root);
  const draw = () => {
    let t = C.filterTable(table, q); if (sort) t = C.sortTable(t, sort, asc);
    info.textContent = `${t.rows.length} rows · ${t.columns.length} columns`;
    wrap.innerHTML = `<table><thead><tr>${t.columns.map(c => `<th data-c="${esc(c)}">${esc(c)}${sort === c ? (asc ? ' ▲' : ' ▼') : ''}</th>`).join('')}</tr></thead>
      <tbody>${t.rows.map(r => `<tr>${r.map(v => `<td>${esc(v)}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
  };
  wrap.onclick = e => { const c = e.target.closest('th')?.dataset.c; if (!c) return; asc = sort === c ? !asc : false; sort = c; draw(); };
  $('input', root).oninput = e => { q = e.target.value; draw(); };
  $('button', root).onclick = () => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([C.tableToCSV(table)], { type: 'text/csv' })); a.download = `${name}.csv`; a.click();
  };
  draw(); return root;
}

async function loadInto(el, fn) {
  el.innerHTML = '<p class="muted">Loading…</p>';
  try { el.replaceChildren(await fn()); }
  catch (e) { el.innerHTML = `<p class="err">${esc(e.message)} <button class="ghost" id="retry">Retry</button></p>`; $('#retry', el).onclick = () => loadInto(el, fn); }
}
const typeToggle = (cur) => `<select id="type"><option value="batter" ${cur === 'batter' ? 'selected' : ''}>Batters</option><option value="pitcher" ${cur === 'pitcher' ? 'selected' : ''}>Pitchers</option></select>`;

const views = {
  leaderboards() {
    const groups = {}; C.LEADERBOARDS.forEach(l => (groups[l.group] ||= []).push(l));
    return h(`<div>${Object.entries(groups).map(([g, ls]) => `<h2>${g}</h2><div class="grid">${ls.map(l =>
      `<div class="card"><a href="#/lb/${l.path}">${l.title}</a><span class="muted">${l.path}</span></div>`).join('')}</div>`).join('')}</div>`);
  },
  lb(path) {
    const lb = C.LEADERBOARDS.find(l => l.path === path); if (!lb) return h('<p class="err">Unknown leaderboard</p>');
    const root = h(`<div><h2>${lb.title}</h2><div class="bar">${lb.type ? typeToggle('batter') : ''}</div><div id="out"></div></div>`);
    const run = () => loadInto($('#out', root), async () =>
      tableView(await getTable(`leaderboard/${lb.path}`, C.leaderboardParams(lb, year(), $('#type', root)?.value)), lb.path));
    $('#type', root)?.addEventListener('change', run); run(); return root;
  },
  custom() {
    const chosen = new Set(['xwoba', 'woba', 'exit_velocity_avg', 'barrel_batted_rate']);
    const root = h(`<div><h2>Custom Leaderboard</h2><div class="bar">${typeToggle('batter')}<button id="go">Run</button>
      <button class="ghost" id="all">Select all</button><button class="ghost" id="none">Clear</button></div>
      <div class="chips">${C.CUSTOM_METRICS.map(m => `<label><input type="checkbox" value="${m}" ${chosen.has(m) ? 'checked' : ''}>${m}</label>`).join('')}</div>
      <br><div id="out"></div></div>`);
    const boxes = [...root.querySelectorAll('.chips input')];
    $('#all', root).onclick = () => boxes.forEach(b => b.checked = true);
    $('#none', root).onclick = () => boxes.forEach(b => b.checked = false);
    const run = () => loadInto($('#out', root), async () => {
      const metrics = boxes.filter(b => b.checked).map(b => b.value);
      return tableView(await getTable('leaderboard/custom', C.customParams(year(), $('#type', root).value, metrics)), 'custom');
    });
    $('#go', root).onclick = run; run(); return root;
  },
  players() {
    const root = h(`<div><h2>Players</h2><div class="bar"><input id="q" type="search" placeholder="Search any player…" autofocus></div><div class="grid" id="res"></div></div>`);
    let timer; $('#q', root).oninput = e => { clearTimeout(timer); timer = setTimeout(async () => {
      const v = e.target.value.trim(), res = $('#res', root); if (v.length < 2) return res.innerHTML = '';
      try { const j = JSON.parse(await get('player/search-all', { search: v }));
        res.innerHTML = C.normalizePlayers(j).map(p => `<div class="card"><a href="#/player/${p.id}/${encodeURIComponent(p.name)}">${esc(p.name)}</a><span class="muted">${esc(p.meta)}</span></div>`).join('') || '<p class="muted">No matches</p>';
      } catch (err) { res.innerHTML = `<p class="err">${esc(err.message)}</p>`; } }, 300); };
    return root;
  },
  player(id, name) {
    name = decodeURIComponent(name || id);
    const root = h(`<div><h2>${esc(name)}</h2><div class="bar"><select id="role"><option value="batter">Hitting</option><option value="pitcher">Pitching</option></select></div><div id="out"></div></div>`);
    const run = () => loadInto($('#out', root), async () => {
      const role = $('#role', root).value;
      const specs = C.splitSpecs(role);
      const results = await Promise.all(specs.map(async ([label, f]) => {
        try { return [label, await getTable('statcast_search/csv', C.statcastParams({ role, playerID: id, seasons: [year()], groupBy: 'name', ...f }))]; }
        catch (e) { return [label, { error: e.message }]; }
      }));
      const box = h('<div class="splits"></div>');
      for (const [label, t] of results) {
        const card = h(`<div class="card"><h3>${label}</h3></div>`);
        if (t.error) card.append(h(`<p class="err">${esc(t.error)}</p>`));
        else if (!t.rows.length) card.append(h('<p class="muted">No data</p>'));
        else card.append(h(`<dl>${t.columns.map((c, i) => `<dt>${esc(c)}</dt><dd>${esc(t.rows[0][i])}</dd>`).join('')}</dl>`));
        box.append(card);
      }
      return box;
    });
    $('#role', root).onchange = run; run(); return root;
  },
  statcast() {
    const root = h(`<div><h2>Statcast Search</h2><div class="bar">
      <label>Role <select id="role"><option>batter</option><option>pitcher</option></select></label>
      <label>Pitcher throws <select id="pt"><option value="">Any</option><option>L</option><option>R</option></select></label>
      <label>Batter stands <select id="bs"><option value="">Any</option><option>L</option><option>R</option></select></label>
      <label>Pitch <select id="pty"><option value="">Any</option>${C.PITCH_TYPES.map(p => `<option>${p}</option>`).join('')}</select></label>
      <label>Home/Road <select id="hr"><option value="">Any</option><option>Home</option><option>Road</option></select></label>
      <label>Group by <select id="gb">${C.GROUP_BY.map(g => `<option>${g}</option>`).join('')}</select></label>
      <label>From <input type="date" id="d1"></label><label>To <input type="date" id="d2"></label>
      <button id="go">Run</button></div><div id="out"></div></div>`);
    const run = () => loadInto($('#out', root), async () => {
      const v = id => $(id, root).value;
      const q = { role: v('#role'), seasons: [year()], pitcherThrows: v('#pt'), batterStands: v('#bs'), pitchTypes: v('#pty') ? [v('#pty')] : [],
        homeAway: v('#hr'), groupBy: v('#gb'), startDate: v('#d1'), endDate: v('#d2') };
      return tableView(await getTable('statcast_search/csv', C.statcastParams(q)), 'statcast');
    });
    $('#go', root).onclick = run; return root;
  },
};

const TABS = [['leaderboards', 'Leaderboards'], ['custom', 'Custom'], ['players', 'Players'], ['statcast', 'Statcast']];
function route() {
  const [, name = 'leaderboards', ...args] = location.hash.slice(1).split('/');
  const key = name === 'lb' ? 'leaderboards' : name;
  $('#nav').innerHTML = TABS.map(([k, t]) => `<a href="#/${k}" class="${k === key || (k === 'players' && name === 'player') ? 'on' : ''}">${t}</a>`).join('');
  const fn = views[name] || views.leaderboards;
  $('#view').replaceChildren(fn(...args));
}
addEventListener('hashchange', route);
route();
