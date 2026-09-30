// Pure data logic (no DOM) so it can be unit-tested in Node.
export function parseCSV(text) {
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
  const rows = []; let row = [], f = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"') { if (text[i + 1] === '"') { f += '"'; i++; } else q = false; } else f += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(f); f = ''; }
    else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; row.push(f); f = ''; rows.push(row); row = []; }
    else f += c;
  }
  if (f || row.length) { row.push(f); rows.push(row); }
  return rows.filter(r => !(r.length === 1 && r[0] === ''));
}
export function toTable(csv) {
  const [columns = [], ...body] = parseCSV(csv);
  const rows = body.map(r => columns.map((_, i) => r[i] ?? ''));
  return { columns, rows };
}
export function sortTable(t, col, asc) {
  const c = t.columns.indexOf(col); if (c < 0) return t;
  const rows = [...t.rows].sort((a, b) => {
    const x = a[c], y = b[c], nx = x !== '' && !isNaN(x), ny = y !== '' && !isNaN(y);
    if (nx && ny) return asc ? x - y : y - x;
    if ((x === '') !== (y === '')) return x === '' ? 1 : -1;
    return asc ? x.localeCompare(y) : y.localeCompare(x);
  });
  return { ...t, rows };
}
export const filterTable = (t, q) => {
  q = q.trim().toLowerCase();
  return q ? { ...t, rows: t.rows.filter(r => r.some(v => v.toLowerCase().includes(q))) } : t;
};
export function tableToCSV(t) {
  const esc = s => /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  return [t.columns, ...t.rows].map(r => r.map(esc).join(',')).join('\n');
}

export const LEADERBOARDS = [
  ['Expected Statistics', 'expected_statistics', 'Hitting & Pitching', { type: true }],
  ['Exit Velocity & Barrels', 'statcast', 'Hitting & Pitching', { type: true }],
  ['Percentile Rankings', 'percentile-rankings', 'Hitting & Pitching', { type: true }],
  ['Bat Tracking', 'bat-tracking', 'Hitting'], ['Swing/Take', 'swing-take', 'Hitting'], ['Home Runs', 'home-runs', 'Hitting'],
  ['Pitch Arsenals', 'pitch-arsenals', 'Pitching', { params: { type: 'avg_speed' } }],
  ['Pitch Arsenal Stats', 'pitch-arsenal-stats', 'Pitching', { type: true }],
  ['Pitch Movement', 'pitch-movement', 'Pitching', { params: { pitch_type: 'FF' } }],
  ['Active Spin', 'active-spin', 'Pitching'], ['Pitcher Running Game', 'pitcher-running-game', 'Pitching'],
  ['Sprint Speed', 'sprint_speed', 'Running', { params: { min: '10' } }], ['Baserunning', 'baserunning', 'Running'],
  ['Outs Above Average', 'outs_above_average', 'Fielding', { yearParam: 'startYear', params: { type: 'Fielder', split: 'no', range: 'year', min: 'q' } }],
  ['Catch Probability', 'catch_probability', 'Fielding'], ['Arm Strength', 'arm-strength', 'Fielding'],
  ['Catcher Framing', 'catcher-framing', 'Catching'], ['Catcher Throwing', 'catcher_throwing', 'Catching'],
  ['Catcher Blocking', 'catcher-blocking', 'Catching'], ['Catcher Pop Time', 'poptime', 'Catching'],
].map(([title, path, group, o = {}]) => ({ title, path, group, type: !!o.type, yearParam: o.yearParam || 'year', params: o.params || {} }));

export const CUSTOM_METRICS = ['player_age','pa','ab','hit','single','double','triple','home_run','strikeout','walk','k_percent','bb_percent','batting_avg','slg_percent','on_base_percent','on_base_plus_slg','isolated_power','babip','b_rbi','b_run','xba','xslg','xwoba','xobp','xiso','exit_velocity_avg','launch_angle_avg','sweet_spot_percent','barrel_batted_rate','solidcontact_percent','flareburner_percent','poorlyunder_percent','poorlytopped_percent','poorlyweak_percent','hard_hit_percent','avg_best_speed','avg_hyper_speed','z_swing_percent','z_swing_miss_percent','oz_swing_percent','oz_swing_miss_percent','oz_contact_percent','out_zone_swing_miss','out_zone_percent','out_zone','meatball_swing_percent','meatball_percent','pitch_count_offspeed','pitch_count_fastball','pitch_count_breaking','iz_contact_percent','in_zone_percent','edge_percent','whiff_percent','swing_percent','pull_percent','straightaway_percent','opposite_percent','groundballs_percent','flyballs_percent','linedrives_percent','popups_percent','woba','wobacon','xwobacon','bacon','xbacon','sprint_speed','n','p_game','p_formatted_ip','p_win','p_loss','p_save','p_era','p_opp_batting_avg','p_strikeout','p_walk','p_k_percent','p_bb_percent','whip','xera','p_total_pitches','pitch_hand','batter_run_value_per_100','p_run_value','fastball_avg_speed'];

const pipe = a => (a && a.length ? a.join('|') + '|' : '');

/** Statcast Search params. Every split is a filter + group_by. */
export function statcastParams(q) {
  const p = {
    all: 'true', hfSea: pipe(q.seasons), hfPT: pipe(q.pitchTypes), hfAB: pipe(q.events), hfBBT: '', hfZ: pipe(q.zones),
    hfInn: pipe(q.innings), hfOuts: pipe(q.outs), hfBBL: '', hfC: '', hfStrikes: pipe(q.strikes), hfBalls: pipe(q.balls),
    hfRO: pipe(q.runnersOn), player_type: q.role || 'batter', stadium: '',
    game_date_gt: q.startDate || '', game_date_lt: q.endDate || '',
    hfTeam: q.team ? q.team + '|' : '', hfOpponent: q.opponent ? q.opponent + '|' : '', home_road: q.homeAway || '',
    pitcher_throws: q.pitcherThrows || '', batter_stands: q.batterStands || '',
    group_by: q.groupBy || 'name', sort_col: q.sortColumn || 'pitches', sort_order: 'desc',
    min_pitches: String(q.minPitches || 0), min_results: String(q.minResults || 0), type: 'details',
  };
  if (q.playerID) p[(q.role || 'batter') === 'batter' ? 'batters_lookup[]' : 'pitchers_lookup[]'] = String(q.playerID);
  return p;
}
export const GROUP_BY = ['name','team','pitch-type','month','venue','count','name-event','name-year','name-team','name-pitch-type'];
export const PITCH_TYPES = ['FF','SI','FC','SL','ST','CU','CH','FS','KC','SV'];

export function splitSpecs(role) {
  const lr = role === 'batter'
    ? [['vs LHP', { pitcherThrows: 'L' }], ['vs RHP', { pitcherThrows: 'R' }]]
    : [['vs LHB', { batterStands: 'L' }], ['vs RHB', { batterStands: 'R' }]];
  return [['Overall', {}], ...lr, ['Home', { homeAway: 'Home' }], ['Road', { homeAway: 'Road' }],
    ['RISP', { runnersOn: ['RISP'] }], ['Bases Empty', { runnersOn: ['Empty'] }],
    ['Two Strikes', { strikes: [2] }], ['Ahead in Count', { balls: [2, 3], strikes: [0, 1] }]];
}

export function leaderboardParams(lb, year, type = 'batter') {
  const p = { [lb.yearParam]: String(year), csv: 'true', ...lb.params };
  if (lb.yearParam === 'startYear') p.endYear = String(year);
  if (lb.type) { p.type = type; p.min = p.min || 'q'; }
  return p;
}
export const customParams = (year, type, metrics, min = 'q') =>
  ({ year: String(year), type, filter: '', min, selections: metrics.join(','), chart: 'false', csv: 'true' });

/** Normalise whatever shape player/search-all returns into {id,name,meta}. */
export function normalizePlayers(json) {
  const list = Array.isArray(json) ? json : (json.players || json.results || []);
  return list.map(p => ({
    id: p.id ?? p.player_id ?? p.key_mlbam ?? p.mlbam,
    name: p.name ?? p.player_name ?? p.fullName ?? '',
    meta: [p.pos, p.team ?? p.teamAbbr].filter(Boolean).join(' · '),
  })).filter(p => p.id && p.name);
}
