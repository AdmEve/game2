'use strict';
const http = require('http');
const { WebSocketServer } = require('ws');
const G = require('./game');

const PORT = process.env.PORT || 8080;
// Test/dev overrides only. Unset in real play, so the rules' defaults apply.
const TURN_SECONDS = Number(process.env.TURN_SECONDS) || null;
const RESULT_PAUSE_MS = Number(process.env.RESULT_PAUSE_MS) || null;
const rooms = new Map();
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
    order: [], turnIdx: 0,
    turnNo: 0,                // 1-based number of the turn being played or just finished
    word: null,               // NEVER broadcast
    usedWords: new Set(),     // offered this game, not offered again
    mask: null,
    strokes: [],
    guessed: new Set(),
    scoreGain: {},
    teamScore: [0, 0],
    mvp: {},
    deadline: 0,
    timers: [],
  };
  rooms.set(r.code, r);
  return r;
}

const turnLen = r => r.turnLen || (r.mode === 'team' ? 60 : 80);
const alive = r => r.players.filter(p => p.ws && p.ws.readyState === 1);
const drawer = r => r.order[r.turnIdx] || null;
const guessersOf = r => {
  const d = drawer(r);
  return r.mode === 'team'
    ? r.players.filter(p => p !== d && p.team === d.team)
    : r.players.filter(p => p !== d);
};
/** Guessers still in the room who solved this turn (a departed solver no longer counts). */
const solvedCount = r => guessersOf(r).filter(q => r.guessed.has(q)).length;
const opponentsOf = r => r.players.filter(p => p.team !== drawer(r).team);

/** Can this player submit a guess right now? */
function mayGuess(r, p) {
  const d = drawer(r);
  if (!d || p === d) return false;
  if (r.phase === 'stealing') return r.mode === 'team' && p.team !== d.team;
  if (r.phase !== 'drawing') return false;
  return r.mode === 'team' ? p.team === d.team : true;
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
  score: p.score, solved: p.solved, hostMuted: p.hostMuted,
});

function roomState(r) {
  return {
    t: 'room', code: r.type === 'private' ? r.code : null, type: r.type,
    mode: r.mode, phase: r.phase, hostId: r.hostId,
    players: r.players.map(publicPlayer),
    teamScore: r.teamScore,
    turn: r.turnNo, turns: r.order.length,
  };
}
const pushState = r => broadcast(r, roomState(r));

/* ---------- turn lifecycle ---------- */
function startGame(r) {
  r.order = [];
  for (let i = 0; i < r.rounds; i++) r.players.forEach(p => r.order.push(p));
  r.turnIdx = 0;
  r.players.forEach(p => { p.score = 0; });
  r.teamScore = [0, 0]; r.mvp = {};
  r.usedWords = new Set();
  nextTurn(r);
}

function nextTurn(r) {
  clearTimers(r);
  if (r.turnIdx >= r.order.length) return endGame(r);
  const d = drawer(r);
  r.turnNo = r.turnIdx + 1;
  r.phase = 'choosing';
  r.word = null; r.mask = null; r.strokes = [];
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

  send(d, { t: 'turn', role: 'drawer', word, seconds: len, team: d.team });
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
        if (ch !== ' ' && ch !== '\u200c' && r.mask[i] === null) open.push(i);
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
  broadcast(r, {
    t: 'results', word, gains: r.scoreGain,
    players: r.players.map(publicPlayer), teamScore: r.teamScore,
    final: r.turnIdx >= r.order.length,
  });
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
  broadcast(r, {
    t: 'over', mode: r.mode, winner, teamScore: r.teamScore,
    players: r.players.map(publicPlayer), mvp: mvpId ? mvpId[0] : null,
  });
}

/* ---------- message handling ---------- */
function onMessage(p, raw) {
  let m; try { m = JSON.parse(raw) } catch { return }
  const r = p.room;

  if (m.t === 'join') return; // handled at connect

  if (!r) return;
  const d = drawer(r);

  switch (m.t) {
    case 'mode': {
      if (p.id !== r.hostId || r.phase !== 'lobby') return;
      if (r.type === 'public') return;                 // teams need a stable group
      r.mode = m.mode === 'team' ? 'team' : 'ffa';
      r.players.forEach((pl, i) => { pl.team = i % 2 });
      return pushState(r);
    }
    case 'start': {
      if (p.id !== r.hostId || r.phase !== 'lobby') return;
      if (r.players.length < 2) return send(p, { t: 'error', why: 'need_players' });
      return startGame(r);
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
    case 'stroke': {
      if (r.phase !== 'drawing' || p !== d) return;     // only the drawer draws
      r.strokes.push(m.s);
      return broadcast(r, { t: 'stroke', s: m.s }, p);
    }
    case 'clear': {
      if (r.phase !== 'drawing' || p !== d) return;
      r.strokes = [];
      return broadcast(r, { t: 'clear' }, p);
    }
    case 'guess': {
      const text = String(m.text || '').slice(0, 60);
      if (!text) return;
      if (!mayGuess(r, p)) return send(p, { t: 'denied', why: 'not_your_turn' });
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

/* ---------- wiring ---------- */
const server = http.createServer();
// A long stroke is ~25 KB; anything far bigger is abuse, and ws drops the connection.
const wss = new WebSocketServer({ server, maxPayload: 256 * 1024 });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://x');
  const name = (url.searchParams.get('name') || 'بازیکن').slice(0, 14);
  const avatar = url.searchParams.get('avatar') || '🦊';
  const want = url.searchParams.get('code');
  const type = url.searchParams.get('type') === 'public' ? 'public' : 'private';

  let room;
  if (want && rooms.has(want)) room = rooms.get(want);
  else if (type === 'public') room = [...rooms.values()].find(x => x.type === 'public' && x.phase === 'lobby' && x.players.length < 8) || makeRoom('public');
  else room = makeRoom('private');

  if (room.phase !== 'lobby') { ws.send(JSON.stringify({ t: 'error', why: 'in_progress' })); return ws.close(); }

  const p = {
    id: 'p' + (nextId++), name, avatar, ws, room,
    score: 0, solved: false, hostMuted: false,
    team: room.players.length % 2,
  };
  room.players.push(p);
  if (!room.hostId) room.hostId = p.id;

  send(p, { t: 'you', id: p.id, code: room.type === 'private' ? room.code : null, voice: room.type === 'private' });
  pushState(room);

  ws.on('message', raw => onMessage(p, raw));
  // Without this, one bad socket (oversized frame, reset) crashes every room.
  // 'close' always follows an error, and that does the cleanup.
  ws.on('error', () => {});
  ws.on('close', () => removePlayer(room, p));
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
