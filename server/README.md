# نقاشی بکش — game server

Authoritative multiplayer server. The answer word lives here and is never sent
to guessers, so the client cannot be trusted or tampered with.

## Run it

```bash
npm install
node server.js            # listens on :8080, prints the LAN address for phones
PORT=3000 node server.js  # or pick a port
npm run bundle            # dist/naqashi-server.js: one file, runs with plain `node`
```

Test with simulated clients:

```bash
node test.js              # 45 assertions, no browser needed
```

`TURN_SECONDS` and `RESULT_PAUSE_MS` shorten turns for tests; leave them unset for real play.

Playtesting on your home wifi: run the server on your laptop, find your local
IP (`hostname -I` on Linux, `ipconfig getifaddr en0` on macOS), and have phones
connect to `ws://<that-ip>:8080`. No hosting account required.

## Files

- `game.js` — pure rules: Persian normaliser, `judge()`, scoring maths. No I/O,
  so it can be unit-tested and reused by any transport.
- `server.js` — rooms, turn lifecycle, message handling, permissions.
- `test.js` — integration tests driving real WebSocket clients.

## Connecting

```
ws://host:8080/?name=پویا&avatar=🦊               → creates a private room
ws://host:8080/?name=پویا&code=7K4M2              → joins that private room
ws://host:8080/?name=پویا&type=public             → matchmaking into a public room
```

## Protocol

Client → server:

| message | who may send it |
|---|---|
| `{t:'mode', mode:'ffa'\|'team'}` | host, in lobby only |
| `{t:'start'}` | host, needs ≥2 players |
| `{t:'pick', i}` / `{t:'skip'}` | current drawer, while choosing |
| `{t:'stroke', s}` / `{t:'clear'}` / `{t:'done'}` | current drawer, while drawing |
| `{t:'guess', text}` | anyone allowed to guess right now |
| `{t:'mute', id}` / `{t:'kick', id}` | host, private rooms only |

Server → client:

| message | sent to |
|---|---|
| `{t:'you', id, code, voice}` | on connect; `voice` is false in public rooms |
| `{t:'room', ...}` | everyone, whenever lobby state changes |
| `{t:'choices', words}` | **drawer only** |
| `{t:'turn', role, word?, mask?, seconds}` | `word` only to the drawer; everyone else gets `mask` |
| `{t:'hint', i, ch}` | **guessers only** — watchers are not helped |
| `{t:'chat', ..., scope}` | `scope:'private'` = near-miss, `'solvers'` = solver-only |
| `{t:'solved', from, name, points}` | everyone — names the solver, never the word |
| `{t:'steal', seconds, canGuess, points}` | everyone, when a team turn expires unsolved |
| `{t:'results', word, gains, teamScore}` | everyone, at turn end (word revealed here) |
| `{t:'over', winner, mvp, teamScore}` | everyone, at game end |

## Rules the server enforces

- The word is held server-side and cleared at turn end. Guessers get a letter
  mask; hints fill it in one letter at a time.
- Guessing is gated: in team mode only the drawer's own team may guess, and
  during a steal only the opposing team may.
- A player cannot score the same word twice.
- Once you solve, your chat reaches only other solvers — no accidental spoiling.
- Only the current drawer's strokes are accepted and rebroadcast.
- Team turns are 60s, free-for-all 80s, steal window 10s for a flat 75 points.
- No word is offered twice in one game (until a difficulty tier runs out).
- Leaving mid-game: the leaver's future turns are dropped; if they were drawing,
  the turn ends; if the last unsolved guesser leaves, the turn ends; with one
  player left the game ends.
- Messages over 256 KB close that connection (and only that one).

## Not done yet

- **Voice.** The `{t:'mic'}` message tells the drawer their mic is off in team
  mode, but no audio is routed. That needs an SFU (LiveKit or mediasoup) beside
  this server; the mute rules above then become routing rules there.
- **Persistence.** Rooms are in memory and vanish on restart. Fine for
  playtesting; add Redis before running more than one server process.
- **Reconnection.** A dropped player is removed rather than given a grace
  period to rejoin.
- **Rate limiting** on `guess` and `stroke` (size is capped, rate is not).
- **Play again.** After `over` the room stays over; start a new room.
