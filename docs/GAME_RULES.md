# Game rules and protocol

Source of truth for behaviour is `server/game.js` + `server/server.js`; this explains the intent.

## Structure

A game is `rounds` rounds (default 2). In each round every player draws once, so
4 players × 2 rounds = 8 turns. The room's `order` array lists drawers; `turnIdx` indexes it.
No elimination: the result is a ranked scoreboard (free-for-all) or two team totals.

## A turn

1. **choosing** — drawer gets 3 words (easy / medium / hard); 20 s to pick, else the first is auto-picked. Drawer may **skip** for 0 points.
2. **drawing** — 80 s (free-for-all) or 60 s (team). Guessers see a letter mask; hints reveal one letter at ~35 % and ~65 % of elapsed time, **to guessers only**.
3. **(team only) stealing** — if the clock runs out with no correct guess, the opposing team gets 10 s.
4. **results** — word revealed, gains shown; after `resultPause` (default 5 s) the next turn starts automatically, or the game ends after the last turn.

A turn ends early when: (free-for-all) every guesser has solved; (team) the first correct guess lands;
or the drawer taps done.

## Scoring

| Event | Points |
|---|---|
| Guesser solves | `round(100 + secsLeft/turnLen × 200)` → 300 instant, 200 half-time, 100 at buzzer |
| Drawer (free-for-all) | `round(150 × solved / possibleGuessers)`; 0 if the turn was skipped |
| Team solve | same guesser formula, added to that team's total; individual solves tracked for MVP |
| Steal | flat 75 to the stealing team |

Rationale: speed is worth 3× lateness (tension); the drawer's pay depends on how many guessed
(kills unguessable scribbles and writing the word on the canvas); steal is deliberately less
than a normal solve so failing still costs the drawing team.

## Teams

Alternating assignment by join order (A, B, A, B…). Turns alternate teams because `order` cycles
through `players` in join order. Only the drawer's team may type guesses; the other team watches.
Drawer's mic is off in team mode. Winner = higher team total; ties are draws. MVP = most solves.

## Guess verdicts (server only)

`judge(guess, word)` → `correct | close | wrong`.
- Normalise both sides: strip harakat, tatweel, ZWNJ and bidi controls; fold Persian/Arabic digits; ي→ی, ك→ک; all alef forms → ا; ؤ→و, ئ→ی, ء removed; ة/ۀ→ه; remove whitespace; lowercase.
- Compare against the word and its `ALIASES`; Levenshtein distance 0 = correct.
- `close` if distance ≤ `max(1, floor(len/4))`. **Close is shown only to the guesser** (leak guard).
- A player cannot score the same turn twice. After solving, chat is `scope:'solvers'`.

## Rooms and voice

| | Private (invite code) | Public (matchmaking) |
|---|---|---|
| Voice | Yes | **No** — text only |
| Host mute-for-all / kick | Yes | No |
| Room code shown | Yes | No |
| Modes | FFA or team | FFA (teams need stable groups) |

Local mute (this device only) and **report** exist in both. Reporting must be real before public voice is ever considered.

## Protocol

WebSocket JSON. Connect: `ws://host:8080/?name=…&avatar=…` (+ `&code=ABCDE` to join, `&type=public` for matchmaking).

Client → server

| message | who / when |
|---|---|
| `{t:'mode', mode:'ffa'\|'team'}` | host, lobby only |
| `{t:'start'}` | host, ≥2 players |
| `{t:'pick', i}` / `{t:'skip'}` | drawer, choosing |
| `{t:'stroke', s}` / `{t:'clear'}` / `{t:'done'}` | drawer, drawing |
| `{t:'guess', text}` | whoever `mayGuess` |
| `{t:'mute', id}` / `{t:'kick', id}` | host, private only |

Stroke `s`: `{c:'#rrggbb', w:number, p:[{x,y}…]}` with x,y normalised 0..1.

Server → client

| message | to |
|---|---|
| `you {id, code, voice}` | on connect |
| `room {mode, phase, hostId, players[], teamScore, turn, turns}` | all, on any lobby/turn change |
| `choices {words}` | drawer only |
| `waiting {drawer, drawerName}` | everyone but the drawer |
| `turn {role, word?, mask?, seconds, team, drawer, drawerName}` | `word` drawer only; others get `mask` |
| `hint {i, ch}` | guessers only |
| `stroke {s}` / `clear` | all but drawer |
| `chat {from,name,text,kind?,scope?}` | `scope:'private'` near-miss, `'solvers'` solver chat |
| `solved {from,name,points}` | all — never carries the word |
| `youSolved {points,word}` | the solver |
| `steal {seconds,canGuess,forTeam,points}` | all |
| `denied {why}` | a guess from someone not allowed |
| `results {word,gains,players,teamScore,final}` | all |
| `over {mode,winner,teamScore,players,mvp}` | all |
| `mic {allowed}` | drawer |
| `kicked`, `error {why}` | individual |

Known protocol quirk: the `players[].score` in team mode stays 0 (team totals are in `teamScore`).
