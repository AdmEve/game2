'use strict';
const WebSocket = require('ws');
const { server, rooms } = require('./server');

const PORT = 8099;
let pass = 0, fail = 0;
const ok = (c, msg) => { c ? pass++ : fail++; console.log((c ? '  PASS ' : '  FAIL ') + msg) };
const sleep = ms => new Promise(r => setTimeout(r, ms));

function client(name, opts = {}) {
  const q = new URLSearchParams({ name, ...opts });
  const ws = new WebSocket(`ws://127.0.0.1:${PORT}/?${q}`);
  const c = { name, ws, inbox: [], id: null, code: null, word: null, mask: null, role: null };
  ws.on('message', raw => {
    const m = JSON.parse(raw);
    c.inbox.push(m);
    if (m.t === 'you') { c.id = m.id; c.code = m.code }
    if (m.t === 'choices') c.choices = m.words;
    if (m.t === 'turn') { c.role = m.role; if (m.word) c.word = m.word; if (m.mask) c.mask = m.mask }
    if (m.t === 'room') c.room = m;
  });
  c.send = o => ws.send(JSON.stringify(o));
  c.ready = new Promise(res => ws.on('open', res));
  c.got = t => c.inbox.filter(m => m.t === t);
  c.last = t => c.got(t).slice(-1)[0];
  return c;
}

(async () => {
  await new Promise(r => server.listen(PORT, r));
  console.log('\n=== FREE-FOR-ALL ===');

  const A = client('میزبان');           await A.ready; await sleep(60);
  const roomCode = A.code;
  const B = client('سارا', { code: roomCode });   await B.ready;
  const C = client('میلاد', { code: roomCode });  await C.ready;
  const D = client('نگار', { code: roomCode });   await D.ready;
  await sleep(120);

  ok(A.room.players.length === 4, 'four players joined one room');
  ok(A.room.hostId === A.id, 'first joiner is host');

  // non-host cannot start
  B.send({ t: 'start' }); await sleep(80);
  ok(A.room.phase === 'lobby', 'non-host cannot start the game');

  A.send({ t: 'start' }); await sleep(120);
  const drawerC = [A, B, C, D].find(c => c.choices);
  ok(!!drawerC, 'drawer received word choices');
  const others = [A, B, C, D].filter(c => c !== drawerC);
  ok(others.every(c => !c.choices), 'non-drawers received no word choices');

  drawerC.send({ t: 'pick', i: 0 }); await sleep(150);
  const secret = drawerC.word;
  ok(!!secret, 'drawer knows the word');
  ok(others.every(c => c.word === null), 'guessers never receive the word');
  ok(others.every(c => Array.isArray(c.mask)), 'guessers receive a letter mask instead');

  // wrong guess is public, close guess is private
  const g1 = others[0];
  g1.send({ t: 'guess', text: 'یک چیز نامربوط' }); await sleep(90);
  ok(others[1].got('chat').some(m => m.text === 'یک چیز نامربوط'), 'wrong guess broadcasts to everyone');

  // correct guess scores
  g1.send({ t: 'guess', text: secret }); await sleep(120);
  const solvedMsg = g1.last('youSolved');
  ok(!!solvedMsg && solvedMsg.points >= 100 && solvedMsg.points <= 300,
    `correct guess scored ${solvedMsg && solvedMsg.points} (100–300)`);
  ok(others[1].got('solved').length === 1, 'others are told who solved, not what the word was');
  ok(!others[1].got('solved')[0].word, 'the solved announcement carries no word');

  // double scoring blocked
  const before = solvedMsg.points;
  g1.send({ t: 'guess', text: secret }); await sleep(100);
  ok(g1.got('youSolved').length === 1, 'a player cannot score the same word twice');

  // solver messages are scoped to solvers
  g1.send({ t: 'guess', text: 'خیلی راحت بود' }); await sleep(90);
  const leaked = others[1].got('chat').some(m => m.text === 'خیلی راحت بود' && m.scope !== 'solvers');
  ok(!leaked, 'a solver cannot chat to players who are still guessing');

  // drawer-only canvas
  others[1].send({ t: 'stroke', s: { c: '#000', w: 5, p: [{ x: 0, y: 0 }] } }); await sleep(80);
  ok(others[0].got('stroke').length === 0, 'non-drawers cannot draw on the canvas');

  console.log('\n=== TEAM MODE ===');
  [A, B, C, D].forEach(c => c.ws.close()); await sleep(80);

  const T = [client('آ۱'), null, null, null];
  await T[0].ready; await sleep(60);
  const tc = T[0].code;
  T[1] = client('ق۱', { code: tc }); await T[1].ready;
  T[2] = client('آ۲', { code: tc }); await T[2].ready;
  T[3] = client('ق۲', { code: tc }); await T[3].ready;
  await sleep(120);

  T[0].send({ t: 'mode', mode: 'team' }); await sleep(100);
  const teams = T[0].room.players.map(p => p.team);
  ok(JSON.stringify(teams) === '[0,1,0,1]', 'players split into alternating teams ' + JSON.stringify(teams));

  T[0].send({ t: 'start' }); await sleep(150);
  const dr = T.find(c => c.choices);
  dr.send({ t: 'pick', i: 0 }); await sleep(150);
  const w2 = dr.word;
  const drTeam = dr.room.players.find(p => p.id === dr.id).team;
  const mate = T.find(c => c !== dr && c.room.players.find(p => p.id === c.id).team === drTeam);
  const foe = T.find(c => c.room.players.find(p => p.id === c.id).team !== drTeam);

  ok(mate.role === 'guesser', 'teammate of the drawer may guess');
  ok(foe.role === 'watcher', 'opposing team is a watcher, not a guesser');

  foe.send({ t: 'guess', text: w2 }); await sleep(120);
  ok(foe.got('denied').length === 1, 'opposing team guess is rejected while it is not their turn');
  ok(foe.got('youSolved').length === 0, 'rejected guess scores nothing');

  mate.send({ t: 'guess', text: w2 }); await sleep(1300);
  ok(mate.got('youSolved').length === 1, 'teammate scores for the team');
  const ts = mate.last('results').teamScore;
  ok(ts[drTeam] > 0 && ts[1 - drTeam] === 0, `points went to the drawing team only ${JSON.stringify(ts)}`);

  console.log('\n=== STEAL WINDOW ===');
  [...T].forEach(c => c.ws.close()); await sleep(80);

  const S = [client('آ۱'), null, null, null];
  await S[0].ready; await sleep(60);
  const sc = S[0].code;
  S[1] = client('ق۱', { code: sc }); await S[1].ready;
  S[2] = client('آ۲', { code: sc }); await S[2].ready;
  S[3] = client('ق۲', { code: sc }); await S[3].ready;
  await sleep(120);
  // shorten the turn so the clock can actually run out inside a test
  rooms.get(sc).turnLen = 2;
  S[0].send({ t: 'mode', mode: 'team' }); await sleep(80);
  S[0].send({ t: 'start' }); await sleep(150);
  const dr2 = S.find(c => c.choices);
  dr2.send({ t: 'pick', i: 0 }); await sleep(120);
  const w3 = dr2.word;
  const dTeam2 = dr2.room.players.find(p => p.id === dr2.id).team;
  const foe2 = S.find(c => c.room.players.find(p => p.id === c.id).team !== dTeam2);

  await sleep(2400);   // let the turn expire with nobody guessing
  ok(foe2.got('steal').length === 1, 'steal window opens when the drawing team runs out of time');
  ok(foe2.last('steal').canGuess === true, 'the opposing team may guess during the steal');

  foe2.send({ t: 'guess', text: w3 }); await sleep(1300);
  const stole = foe2.last('youSolved');
  ok(stole && stole.points === 75, `steal is worth a flat 75 (got ${stole && stole.points})`);
  const ts2 = foe2.last('results').teamScore;
  ok(ts2[1 - dTeam2] === 75, `stolen points went to the opposing team ${JSON.stringify(ts2)}`);

  console.log('\n=== TURN ADVANCE ===');
  [...S].forEach(c => c.ws.close()); await sleep(80);
  const P1 = client('یک'); await P1.ready; await sleep(60);
  const P2 = client('دو', { code: P1.code }); await P2.ready; await sleep(100);
  rooms.get(P1.code).resultPause = 600;
  P1.send({ t: 'start' }); await sleep(120);
  ok(!!P1.choices, 'turn 1: first player is the drawer');
  P1.send({ t: 'pick', i: 0 }); await sleep(120);
  P2.send({ t: 'guess', text: P1.word }); await sleep(1150);
  ok(P2.room.phase === 'results' && P2.room.turn === 1,
    `results still report the turn just played (got ${P2.room.phase} ${P2.room.turn})`);
  await sleep(900);
  ok(P2.got('choices').length === 1, 'turn 2 starts on its own: the other player is offered words');
  ok(P2.room.turn === 2, 'turn counter advanced to 2 (got ' + P2.room.turn + ')');

  console.log('\n=== LEAVING MID-GAME ===');
  [P1, P2].forEach(c => c.ws.close()); await sleep(80);
  const L1 = client('اول'); await L1.ready; await sleep(60);
  const L2 = client('دوم', { code: L1.code }); await L2.ready;
  const L3 = client('سوم', { code: L1.code }); await L3.ready; await sleep(100);
  rooms.get(L1.code).resultPause = 300;
  L1.send({ t: 'start' }); await sleep(120);
  L1.send({ t: 'pick', i: 0 }); await sleep(120);
  ok(L2.room.turns === 6, 'three players, two rounds: six turns');
  L1.ws.close(); await sleep(150);                 // the drawer walks out mid-turn
  ok(L2.got('results').length === 1, 'drawer leaving ends their turn at once');
  ok(L2.last('results').gains[L1.id] === undefined, 'a drawer who left earns nothing');
  ok(L2.room.turns === 5, `the leaver's future turn is dropped (got ${L2.room.turns} turns)`);
  ok(L2.room.hostId === L2.id, 'host passes to the next player');
  await sleep(500);
  const nd = [L2, L3].find(c => c.got('choices').length);
  ok(!!nd, 'the game carries on with the next drawer');
  nd.send({ t: 'pick', i: 0 }); await sleep(120);
  const other = nd === L2 ? L3 : L2;
  other.ws.close(); await sleep(150);              // only one player left
  ok(nd.last('over') !== undefined, 'a game left with one player ends');

  console.log('\n=== GUESSER LEAVES ===');
  nd.ws.close(); await sleep(80);
  const G1 = client('نقاش'); await G1.ready; await sleep(60);
  const G2 = client('حل‌کن', { code: G1.code }); await G2.ready;
  const G3 = client('رفتنی', { code: G1.code }); await G3.ready; await sleep(100);
  G1.send({ t: 'start' }); await sleep(120);
  G1.send({ t: 'pick', i: 0 }); await sleep(120);
  G2.send({ t: 'guess', text: G1.word }); await sleep(150);
  ok(G2.got('results').length === 0, 'turn waits for the remaining guesser');
  G3.ws.close(); await sleep(150);
  ok(G2.got('results').length === 1, 'when the last unsolved guesser leaves, the turn ends');
  ok(G2.last('results').gains[G1.id] === 150, `drawer is paid on who is still here (got ${G2.last('results').gains[G1.id]})`);

  console.log('\n=== PUBLIC ROOMS ===');
  [G1, G2].forEach(c => c.ws.close()); await sleep(80);
  const U1 = client('عمومی', { type: 'public' }); await U1.ready; await sleep(100);
  U1.send({ t: 'mode', mode: 'team' }); await sleep(80);
  ok(U1.room.mode === 'ffa', 'public rooms stay free-for-all');

  console.log('\n=== PAYLOAD CAP ===');
  let closed = false; U1.ws.on('close', () => { closed = true });
  U1.send({ t: 'guess', text: 'x'.repeat(300 * 1024) }); await sleep(200);
  ok(closed, 'an oversized message closes the connection');
  const after = client('بعدی'); await after.ready; await sleep(80);
  ok(!!after.id, 'and the server is still up for everyone else');
  after.ws.close();

  console.log('\n=== WORD CHOICES ===');
  const G = require('./game');
  const used = new Set(), offered = [];
  for (let i = 0; i < G.WORDS.h.length; i++) offered.push(...G.wordChoices(used));
  ok(new Set(offered).size === offered.length, `no word offered twice in a game (${offered.length} offers)`);
  const more = G.wordChoices(used);
  ok(more.length === 3 && more.every(Boolean), 'a tier that runs out starts over instead of failing');

  console.log(`\n${pass} passed, ${fail} failed\n`);
  process.exit(fail ? 1 : 0);
})();
