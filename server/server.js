'use strict';
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const G = require('./game');

const PORT = process.env.PORT || 8080;
// Test/dev overrides only. Unset in real play, so the rules' defaults apply.
const TURN_SECONDS = Number(process.env.TURN_SECONDS) || null;
const RESULT_PAUSE_MS = Number(process.env.RESULT_PAUSE_MS) || null;
/** How long a dropped player keeps their seat (wifi blip, app switched away). */
const GRACE_MS = process.env.RESUME_GRACE_MS !== undefined ? Number(process.env.RESUME_GRACE_MS) : 30000;

/* Host-adjustable game length. */
const ROUND_CHOICES = [1, 2, 3, 4, 5];
const TURN_CHOICES = [45, 60, 80, 100, 120];

/* Drawing limits: one message carries at most 256 points; a turn at most 60k. */
const MAX_PTS_PER_MSG = 512;       // numbers, i.e. 256 x,y pairs
const MAX_PTS_PER_TURN = 120000;   // numbers
const MAX_STROKES_PER_TURN = 3000;
const COORD_MAX = 10000;           // coordinates are integers 0..10000 (1/10000 of the board)

const rooms = new Map();
const byToken = new Map();
let nextId = 1;

const code = () => Math.random().toString(36).slice(2, 7).toUpperCase();
const now = () => Date.now();

function makeRoom(type, opts = {}) {
  const r = {
    code: code(),
    type,                     // 'private' | 'public'
    mode: 'ffa',              // 'ffa' | 'team'
    players: [],
    hostId: null,
    phase: 'lobby',           // lobby | choosing | drawing | stealing | results | over
    rounds: opts.rounds || 2,
    turnLen: opts.turnLen || TURN_SECONDS,   // null = derive from mode
    resultPause: RESULT_PAUSE_MS,            // null = 5 s
    grace: GRACE_MS,
    order: [], turnIdx: 0,
    turnNo: 0,                // 1-based number of the turn being played or just finished
    word: null,               // NEVER broadcast
    usedWords: new Set(),     // offered in this room, not offered again until a tier runs out
    mask: null,
    strokes: [],              // [{id, c, w, p:[x,y,x,y...]}], in drawing order
    strokeNums: 0,
    guessed: new Set(),
    scoreGain: {},
    teamScore: [0, 0],
    mvp: {},
    deadline: 0,
    clockTotal: 0,
    lastResults: null,
    lastOver: null,
    timers: [],
  };
  rooms.set(r.code, r);
  return r;
}

const turnLen = r => r.turnLen || (r.mode === 'team' ? 60 : 80);
const drawer = r => r.order[r.turnIdx] || null;
const guessersOf = r => {
  const d = drawer(r);
  return r.mode === 'team'
    ? r.players.filter(p => p !== d && p.team === d.team)
    : r.players.filter(p => p !== d);
};
/** Guessers still in the room who solved this turn (a departed solver no longer counts). */
const solvedCount = r => guessersOf(r).filter(q => r.guessed.has(q)).length;

/** Can this player submit a guess right now? */
function mayGuess(r, p) {
  const d = drawer(r);
  if (!d || p === d) return false;
  if (r.phase === 'stealing') return r.mode === 'team' && p.team !== d.team;
  if (r.phase !== 'drawing') return false;
  return r.mode === 'team' ? p.team === d.team : true;
}

function roleOf(r, p) {
  if (p === drawer(r)) return 'drawer';
  return mayGuess(r, p) || (r.phase === 'drawing' && r.mode === 'ffa') ? 'guesser' : 'watcher';
}

/* ---------- rate limiting (token buckets) ---------- */
const LIMITS = {
  draw: { cap: 80, perSec: 50 },    // pts / undo / clear
  guess: { cap: 6, perSec: 2 },     // guesses and chat
};
function allow(p, kind) {
  const L = LIMITS[kind];
  const b = p.buckets[kind] || (p.buckets[kind] = { tokens: L.cap, at: now() });
  const t = now();
  b.tokens = Math.min(L.cap, b.tokens + ((t - b.at) / 1000) * L.perSec);
  b.at = t;
  if (b.tokens < 1) return false;
  b.tokens -= 1;
  return true;
}

/* ---------- transport ---------- */
function send(p, msg) {
  if (p.ws && p.ws.readyState === 1) p.ws.send(JSON.stringify(msg));
}
function broadcast(r, msg, except) {
  for (const p of r.players) if (p !== except) send(p, msg);
}
function clearTimers(r) { r.timers.forEach(clearTimeout); r.timers = []; }
function later(r, ms, fn) { r.timers.push(setTimeout(fn, ms)); }

const publicPlayer = p => ({
  id: p.id, name: p.name, avatar: p.avatar, team: p.team,
  score: p.score, solved: p.solved, hostMuted: p.hostMuted, away: !p.ws,
});

function roomState(r) {
  return {
    t: 'room', code: r.type === 'private' ? r.code : null, type: r.type,
    mode: r.mode, phase: r.phase, hostId: r.hostId,
    players: r.players.map(publicPlayer),
    teamScore: r.teamScore,
    turn: r.turnNo, turns: r.order.length,
    rounds: r.rounds, turnLen: turnLen(r), turnLenAuto: !r.turnLen,
  };
}
const pushState = r => broadcast(r, roomState(r));

/**
 * Everything a (re)connecting player needs to rebuild their screen. The word
 * goes only to the drawer, or to a player who already solved it (rule 1).
 */
function syncFor(r, p) {
  const d = drawer(r);
  const inTurn = ['choosing', 'drawing', 'stealing'].includes(r.phase);
  const msg = { ...roomState(r), t: 'sync', solved: !!p.solved };
  if (inTurn && d) {
    msg.drawer = d.id; msg.drawerName = d.name; msg.team = d.team;
    msg.role = roleOf(r, p);
    if (r.phase === 'choosing' && p === d) msg.choices = d.choices;
    if (r.phase !== 'choosing') {
      if (p === d || p.solved) msg.word = r.word;
      else msg.mask = r.mask;
      msg.strokes = r.strokes;
      msg.seconds = Math.max(0, Math.round((r.deadline - now()) / 1000));
      msg.total = r.clockTotal;
    }
    if (r.phase === 'stealing') {
      msg.steal = { canGuess: mayGuess(r, p), forTeam: d.team === 0 ? 1 : 0, points: G.STEAL_POINTS };
    }
  }
  if (r.phase === 'results') msg.results = r.lastResults;
  if (r.phase === 'over') msg.over = r.lastOver;
  return msg;
}

/* ---------- turn lifecycle ---------- */
function startGame(r) {
  r.order = [];
  for (let i = 0; i < r.rounds; i++) r.players.forEach(p => r.order.push(p));
  r.turnIdx = 0;
  r.players.forEach(p => { p.score = 0; });
  r.teamScore = [0, 0]; r.mvp = {};
  r.lastResults = null; r.lastOver = null;
  nextTurn(r);
}

function nextTurn(r) {
  clearTimers(r);
  if (r.turnIdx >= r.order.length) return endGame(r);
  const d = drawer(r);
  r.turnNo = r.turnIdx + 1;
  r.phase = 'choosing';
  r.word = null; r.mask = null; r.strokes = []; r.strokeNums = 0;
  r.guessed = new Set(); r.scoreGain = {};
  r.players.forEach(p => { p.solved = false; });

  const choices = G.wordChoices(r.usedWords);
  d.choices = choices;
  send(d, { t: 'choices', words: choices });          // only the drawer sees words
  broadcast(r, { t: 'waiting', drawer: d.id, drawerName: d.name }, d);
  pushState(r);
  later(r, 20000, () => { if (r.phase === 'choosing') beginTurn(r, choices[0]); });
}

function beginTurn(r, word) {
  const d = drawer(r);
  r.word = word;
  r.mask = G.maskOf(word);
  r.phase = 'drawing';
  const len = turnLen(r);
  r.deadline = now() + len * 1000;
  r.clockTotal = len;

  send(d, { t: 'turn', role: 'drawer', word, seconds: len, team: d.team, drawer: d.id, drawerName: d.name });
  for (const p of r.players) {
    if (p === d) continue;
    send(p, {
      t: 'turn', role: mayGuess(r, p) ? 'guesser' : 'watcher',
      mask: r.mask, seconds: len, drawer: d.id, drawerName: d.name, team: d.team,
    });
  }
  // the drawer's mic is off in team mode so they can't say the word
  send(d, { t: 'mic', allowed: r.mode !== 'team' });

  scheduleHints(r, len);
  later(r, len * 1000, () => onTimeUp(r));
  pushState(r);
}

function scheduleHints(r, len) {
  [0.65, 0.35].forEach(frac => {
    later(r, (len - Math.round(len * frac)) * 1000, () => {
      if (r.phase !== 'drawing' || !r.word) return;
      const open = [];
      [...r.word].forEach((ch, i) => {
        if (ch !== ' ' && ch !== '‌' && r.mask[i] === null) open.push(i);
      });
      if (!open.length) return;
      const i = open[Math.floor(Math.random() * open.length)];
      r.mask[i] = r.word[i];
      // hints go to guessers only — a watcher on the other team is not helped
      for (const p of r.players) if (mayGuess(r, p)) send(p, { t: 'hint', i, ch: r.word[i] });
    });
  });
}

function onTimeUp(r) {
  if (r.mode === 'team' && r.phase === 'drawing' && r.guessed.size === 0) return startSteal(r);
  finishTurn(r);
}

function startSteal(r) {
  clearTimers(r);
  r.phase = 'stealing';
  r.deadline = now() + G.STEAL_SECONDS * 1000;
  r.clockTotal = G.STEAL_SECONDS;
  const d = drawer(r);
  for (const p of r.players) {
    send(p, {
      t: 'steal', seconds: G.STEAL_SECONDS,
      canGuess: mayGuess(r, p),
      forTeam: d.team === 0 ? 1 : 0, points: G.STEAL_POINTS,
    });
  }
  later(r, G.STEAL_SECONDS * 1000, () => finishTurn(r));
  pushState(r);
}

function award(r, p) {
  if (r.guessed.has(p)) return 0;
  const secsLeft = Math.max(0, Math.round((r.deadline - now()) / 1000));
  const pts = r.phase === 'stealing'
    ? G.STEAL_POINTS
    : G.guessPoints(secsLeft, turnLen(r));
  r.guessed.add(p); p.solved = true;
  r.scoreGain[p.id] = (r.scoreGain[p.id] || 0) + pts;
  if (r.mode === 'team') {
    r.teamScore[p.team] += pts;
    r.mvp[p.id] = (r.mvp[p.id] || 0) + 1;
  } else {
    p.score += pts;
  }
  return pts;
}

function finishTurn(r, skipped) {
  if (r.phase === 'results' || r.phase === 'over') return;
  clearTimers(r);
  const d = drawer(r);
  if (!skipped && r.mode === 'ffa') {
    const dp = G.drawerPoints(solvedCount(r), guessersOf(r).length);
    d.score += dp;
    if (dp) r.scoreGain[d.id] = (r.scoreGain[d.id] || 0) + dp;
  }
  r.phase = 'results';
  const word = r.word;
  r.word = null;                                   // stop holding it
  r.turnIdx++;
  r.lastResults = {
    t: 'results', word, gains: r.scoreGain, drawer: d.id,
    players: r.players.map(publicPlayer), teamScore: r.teamScore,
    final: r.turnIdx >= r.order.length,
  };
  broadcast(r, r.lastResults);
  pushState(r);
  if (r.turnIdx >= r.order.length) later(r, 200, () => endGame(r));
  else later(r, r.resultPause || 5000, () => nextTurn(r));   // show scores, then next drawer
}

function endGame(r) {
  if (r.phase === 'over') return;
  clearTimers(r);
  r.phase = 'over';
  let winner = null;
  if (r.mode === 'team') {
    winner = r.teamScore[0] === r.teamScore[1] ? null : (r.teamScore[0] > r.teamScore[1] ? 0 : 1);
  } else {
    winner = [...r.players].sort((a, b) => b.score - a.score)[0].id;
  }
  const mvpId = Object.entries(r.mvp).sort((a, b) => b[1] - a[1])[0];
  r.lastOver = {
    t: 'over', mode: r.mode, winner, teamScore: r.teamScore,
    players: r.players.map(publicPlayer), mvp: mvpId ? mvpId[0] : null,
  };
  broadcast(r, r.lastOver);
  pushState(r);
}

/** Host taps "play again": same people, back to the lobby, scores reset. */
function resetToLobby(r) {
  clearTimers(r);
  r.phase = 'lobby';
  r.order = []; r.turnIdx = 0; r.turnNo = 0;
  r.word = null; r.mask = null; r.strokes = []; r.strokeNums = 0;
  r.guessed = new Set(); r.scoreGain = {};
  r.teamScore = [0, 0]; r.mvp = {};
  r.lastResults = null; r.lastOver = null;
  r.players.forEach(p => { p.score = 0; p.solved = false; });
  if (r.mode === 'team') r.players.forEach((pl, i) => { pl.team = i % 2 });
  pushState(r);
}

/* ---------- drawing ---------- */
const isCoord = n => Number.isInteger(n) && n >= 0 && n <= COORD_MAX;

/** Validates and stores a batch of points; returns false to drop it. */
function addPoints(r, m) {
  if (!Number.isInteger(m.id) || m.id < 0 || m.id > 1e7) return false;
  const p = m.p;
  if (!Array.isArray(p) || p.length === 0 || p.length % 2 || p.length > MAX_PTS_PER_MSG) return false;
  if (!p.every(isCoord)) return false;
  if (r.strokeNums + p.length > MAX_PTS_PER_TURN) return false;
  let s = r.strokes.length && r.strokes[r.strokes.length - 1].id === m.id ? r.strokes[r.strokes.length - 1] : null;
  if (!s) {
    if (r.strokes.some(x => x.id === m.id)) return false;      // ids only grow; no editing old strokes
    if (r.strokes.length >= MAX_STROKES_PER_TURN) return false;
    if (typeof m.c !== 'string' || !/^#[0-9a-fA-F]{6}$/.test(m.c)) return false;
    if (typeof m.w !== 'number' || !(m.w >= 1 && m.w <= 80)) return false;
    s = { id: m.id, c: m.c, w: m.w, p: [] };
    r.strokes.push(s);
  }
  for (const n of p) s.p.push(n);
  r.strokeNums += p.length;
  return { t: 'pts', id: s.id, c: s.c, w: s.w, p };
}

/* ---------- message handling ---------- */
function onMessage(p, raw) {
  let m; try { m = JSON.parse(raw) } catch { return }
  const r = p.room;
  if (!m || typeof m !== 'object' || !r) return;
  const d = drawer(r);

  switch (m.t) {
    case 'mode': {
      if (p.id !== r.hostId || r.phase !== 'lobby') return;
      if (r.type === 'public') return;                 // teams need a stable group
      r.mode = m.mode === 'team' ? 'team' : 'ffa';
      r.players.forEach((pl, i) => { pl.team = i % 2 });
      return pushState(r);
    }
    case 'settings': {
      if (p.id !== r.hostId || r.phase !== 'lobby') return;
      if (ROUND_CHOICES.includes(m.rounds)) r.rounds = m.rounds;
      if (m.turnLen === null || m.turnLen === 'auto') r.turnLen = null;
      else if (TURN_CHOICES.includes(m.turnLen)) r.turnLen = m.turnLen;
      return pushState(r);
    }
    case 'start': {
      if (p.id !== r.hostId || r.phase !== 'lobby') return;
      if (r.players.length < 2) return send(p, { t: 'error', why: 'need_players' });
      return startGame(r);
    }
    case 'again': {
      if (p.id !== r.hostId || r.phase !== 'over') return;
      return resetToLobby(r);
    }
    case 'leave': {
      removePlayer(r, p);
      if (p.ws) p.ws.close();
      return;
    }
    case 'pick': {
      if (r.phase !== 'choosing' || p !== d) return;
      const w = (p.choices || [])[m.i];
      if (!w) return;
      return beginTurn(r, w);
    }
    case 'skip': {
      if (r.phase !== 'choosing' || p !== d) return;
      return finishTurn(r, true);
    }
    case 'done': {
      if (r.phase !== 'drawing' || p !== d) return;
      return finishTurn(r);
    }
    case 'pts': {
      if (r.phase !== 'drawing' || p !== d) return;     // only the drawer draws
      if (!allow(p, 'draw')) return;
      const out = addPoints(r, m);
      if (out) broadcast(r, out, p);
      return;
    }
    case 'undo': {
      if (r.phase !== 'drawing' || p !== d || !r.strokes.length) return;
      if (!allow(p, 'draw')) return;
      const s = r.strokes.pop();
      r.strokeNums -= s.p.length;
      return broadcast(r, { t: 'undo', id: s.id }, p);
    }
    case 'clear': {
      if (r.phase !== 'drawing' || p !== d) return;
      if (!allow(p, 'draw')) return;
      r.strokes = []; r.strokeNums = 0;
      return broadcast(r, { t: 'clear' }, p);
    }
    case 'guess': {
      const text = String(m.text || '').trim().slice(0, 60);
      if (!text) return;
      if (!mayGuess(r, p)) return send(p, { t: 'denied', why: 'not_your_turn' });
      if (!allow(p, 'guess')) return send(p, { t: 'denied', why: 'slow_down' });
      if (p.solved) {                                   // solvers talk only to solvers
        for (const q of r.players) if (q.solved || q === d)
          send(q, { t: 'chat', from: p.id, name: p.name, text, scope: 'solvers' });
        return;
      }
      const v = G.judge(text, r.word);
      if (v === 'correct') {
        const pts = award(r, p);
        broadcast(r, { t: 'solved', from: p.id, name: p.name, points: pts });
        send(p, { t: 'youSolved', points: pts, word: r.word });
        const done = r.mode === 'team' || solvedCount(r) >= guessersOf(r).length;
        if (done) later(r, 900, () => finishTurn(r));
        return;
      }
      if (v === 'close') {                              // private to the guesser
        return send(p, { t: 'chat', from: p.id, name: p.name, text, kind: 'near', scope: 'private' });
      }
      return broadcast(r, { t: 'chat', from: p.id, name: p.name, text });
    }
    case 'mute': {
      if (p.id !== r.hostId || r.type !== 'private') return;
      const q = r.players.find(x => x.id === m.id); if (!q) return;
      q.hostMuted = !q.hostMuted;
      return pushState(r);
    }
    case 'kick': {
      if (p.id !== r.hostId || r.type !== 'private') return;
      const q = r.players.find(x => x.id === m.id); if (!q || q === p) return;
      send(q, { t: 'kicked' });
      removePlayer(r, q);
      if (q.ws) q.ws.close();
      return;
    }
  }
}

/* ---------- leaving ---------- */
/**
 * Takes a player out of a room at any phase. Their future turns are dropped,
 * a turn they were drawing ends, and a game left with one player ends.
 */
function removePlayer(r, p) {
  if (!r.players.includes(p)) return;
  clearTimeout(p.awayTimer);
  byToken.delete(p.token);
  const playing = ['choosing', 'drawing', 'stealing', 'results'].includes(r.phase);
  const wasDrawing = playing && r.phase !== 'results' && drawer(r) === p;

  r.players = r.players.filter(x => x !== p);
  if (r.hostId === p.id) r.hostId = r.players[0] ? r.players[0].id : null;
  if (!r.players.length) { clearTimers(r); rooms.delete(r.code); return; }

  if (!playing) {
    if (r.phase === 'lobby' && r.mode === 'team') r.players.forEach((pl, i) => { pl.team = i % 2 });
    return pushState(r);
  }

  // Drop their turns that have not started. During results, turnIdx already
  // points at the next turn; otherwise it is the turn in progress.
  const firstFuture = r.phase === 'results' ? r.turnIdx : r.turnIdx + 1;
  r.order = r.order.slice(0, firstFuture).concat(r.order.slice(firstFuture).filter(x => x !== p));

  if (r.players.length < 2) { clearTimers(r); return endGame(r); }
  if (wasDrawing) return finishTurn(r, true);
  if (r.phase === 'drawing' && r.mode === 'ffa' && guessersOf(r).length && solvedCount(r) >= guessersOf(r).length) {
    return finishTurn(r);                          // the only one still guessing left
  }
  pushState(r);
}

/** The socket dropped: keep the seat for r.grace ms so they can resume. */
function onDrop(r, p) {
  p.ws = null;
  if (!r.players.includes(p)) return;
  if (!(r.grace > 0)) return removePlayer(r, p);
  clearTimeout(p.awayTimer);
  p.awayTimer = setTimeout(() => { if (!p.ws) removePlayer(r, p); }, r.grace);
  pushState(r);
}

/* ---------- wiring ---------- */
const server = http.createServer();
// A long stroke batch is a few KB; anything far bigger is abuse, and ws drops the connection.
const wss = new WebSocketServer({ server, maxPayload: 256 * 1024 });

function attach(ws, p) {
  p.ws = ws;
  // Without this, one bad socket (oversized frame, reset) crashes every room.
  // 'close' always follows an error, and that does the cleanup.
  ws.on('error', () => {});
  ws.on('message', raw => onMessage(p, raw));
  ws.on('close', () => { if (p.ws === ws) onDrop(p.room, p); });
}

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://x');

  // Resuming after a drop: same player, same seat, full state.
  const resume = url.searchParams.get('resume');
  if (resume) {
    const p = byToken.get(resume);
    if (!p || !p.room || !p.room.players.includes(p)) {
      ws.on('error', () => {});
      ws.send(JSON.stringify({ t: 'error', why: 'expired' }));
      return ws.close();
    }
    clearTimeout(p.awayTimer);
    const old = p.ws;
    attach(ws, p);
    if (old && old !== ws) old.close();
    const r = p.room;
    send(p, { t: 'you', id: p.id, code: r.type === 'private' ? r.code : null, voice: r.type === 'private', token: p.token });
    send(p, syncFor(r, p));
    return pushState(r);
  }

  const name = (url.searchParams.get('name') || 'بازیکن').slice(0, 14);
  const avatar = (url.searchParams.get('avatar') || '🦊').slice(0, 8);
  const want = (url.searchParams.get('code') || '').toUpperCase();
  const type = url.searchParams.get('type') === 'public' ? 'public' : 'private';

  let room;
  if (want && rooms.has(want)) room = rooms.get(want);
  else if (want) {
    ws.on('error', () => {});
    ws.send(JSON.stringify({ t: 'error', why: 'no_room' }));
    return ws.close();
  } else if (type === 'public') room = [...rooms.values()].find(x => x.type === 'public' && x.phase === 'lobby' && x.players.length < 8) || makeRoom('public');
  else room = makeRoom('private');

  if (room.phase !== 'lobby') {
    ws.on('error', () => {});
    ws.send(JSON.stringify({ t: 'error', why: 'in_progress' }));
    return ws.close();
  }

  const p = {
    id: 'p' + (nextId++), token: crypto.randomBytes(12).toString('hex'),
    name, avatar, ws: null, room,
    score: 0, solved: false, hostMuted: false,
    team: room.players.length % 2, buckets: {}, awayTimer: null,
  };
  byToken.set(p.token, p);
  room.players.push(p);
  if (!room.hostId) room.hostId = p.id;
  attach(ws, p);

  send(p, { t: 'you', id: p.id, code: room.type === 'private' ? room.code : null, voice: room.type === 'private', token: p.token });
  pushState(room);
});

/** LAN addresses phones on the same wifi can use, e.g. ['192.168.1.23']. */
function lanAddresses() {
  const out = [];
  for (const list of Object.values(require('os').networkInterfaces())) {
    for (const a of list || []) if (a.family === 'IPv4' && !a.internal) out.push(a.address);
  }
  return out;
}

function start(port = PORT) {
  server.listen(port, () => {
    console.log('naqashi server on :' + port);
    const ips = lanAddresses();
    if (ips.length) {
      console.log('\nType this into «آدرس سرور» on each phone (same wifi as this computer):');
      for (const ip of ips) console.log(`    ${ip}:${port}`);
      console.log('\nKeep this window open while you play. Ctrl+C stops the server.');
    }
  });
}

if (require.main === module) start();
module.exports = { server, rooms, makeRoom, start };
