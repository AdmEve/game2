# نقاشی بکش (Naqashi Bekesh) — project context for Claude Code

A Persian-language multiplayer party drawing-and-guessing game for Android, aimed at
the Iranian market and distributed through **Cafe Bazaar** and **Myket**. One player
draws a word, the others guess it. Free-for-all and team modes. Owner is building it
solo and wants to make money from it.

**Read `HANDOFF.md` first** for current status, what is verified vs not, and the task order.

## What exists (three pieces)

| Path | What | State |
|---|---|---|
| `lib/`, `pubspec.yaml`, `android/`, `assets/fonts/` | Flutter Android client | **Written, never compiled.** Expect analyzer/build errors on first run. |
| `server/` | Node + `ws` authoritative game server | **Tested.** `cd server && npm install && node test.js` → 29 passing. |
| `prototype/naqashi.html` | Single-file web prototype (bots, no networking) | Working. Reference for UI feel and rules only. Not connected to the server. |
| `.github/workflows/build.yml` | CI that builds the APK on GitHub | Written, never run. Fallback if local toolchain download fails. |
| `docs/` | `GAME_RULES.md`, `MARKET_AND_MONETIZATION.md` | Reference. |

## Environment

- Owner's machine is **Windows 10/11**, user `Asus`, PowerShell. Claude Code binary is at
  `%USERPROFILE%\.local\bin\claude.exe` (not on PATH; launch by full path or fix PATH).
- Owner is in **Iran**. Downloads from Google/GitHub/Maven hosts may be slow, flaky or blocked.
  If a download stalls repeatedly, say so plainly and propose a mirror or the GitHub Actions
  route — do not retry the same multi-GB download in a loop.
- Owner has limited time at the laptop (roughly 8–9 pm local, Asia/Tehran). Long downloads
  should run in the background. **Before stopping each session, update `HANDOFF.md`'s
  "Session log" section** so the next session can resume cold.
- Flutter on Windows needs **Developer Mode** enabled (symlink support for plugins):
  `start ms-settings:developers`.

## Commands

```bash
# server
cd server && npm install && node test.js        # must stay green
node server.js                                  # listens :8080

# app (after first-time setup in HANDOFF.md)
flutter pub get
flutter analyze
flutter run                                     # plugged-in phone
flutter build apk --release --split-per-abi     # output: build/app/outputs/flutter-apk/
```

## Architecture rules — do not break these

1. **The server is authoritative.** The answer word lives only in server memory. Guessers
   receive a letter *mask*, never the word. Only the drawer receives it. The `solved`
   broadcast names the solver and carries no word. `youSolved` reveals it only to the solver.
2. **`judge()` runs on the server** (`server/game.js`). `lib/persian.dart` is a copy for
   offline practice only — never score a networked game with it.
3. **Voice policy:** voice only in **private** rooms (invite code). Public matchmaking is
   **text-only** until a reporting flow exists. Host can mute-for-all and kick in private rooms.
   The drawer's mic is disabled in team mode (they could say the word).
4. **Solved players are gated:** once you solve, your chat reaches only other solvers, and
   (when voice exists) your audio must not reach non-solvers.
5. **Team mode:** only the drawer's team may guess; first correct guess ends the turn; if
   the clock runs out unsolved the opposing team gets a 10 s steal for a flat 75 points.
6. **Fonts are bundled** (Vazirmatn, `assets/fonts/`). Do not switch to `google_fonts` —
   runtime fetching from Google is unreliable in Iran.
7. **All UI is RTL Persian**, numerals via `fa()`. New strings are Persian first.
8. **No Firebase / Google Play Billing / AdMob dependencies.** They are unreliable or
   unusable for the target audience. Use Cafe Bazaar billing (Poolakey) and Tapsell/Adivery.

## Conventions

- Dart: `flutter_lints`; `flutter analyze` should end clean before you call something done.
- Server: plain Node, no framework, `'use strict'`. Pure rules in `game.js`, I/O in `server.js`.
  Every server rule needs a test in `test.js`. Run it before finishing.
- Prefer small, verifiable steps. Say plainly what you verified and what you did not.
- Do not claim an APK exists unless you built it and can name the file path.

## Known gaps (also tracked in HANDOFF.md)

Flutter code uncompiled; app is not yet connected end-to-end to the server; no audio
transport; no billing/ads; no reconnection; no rate limiting; no "play again"; stroke
sync only sends completed strokes; no undo/eraser in the Flutter drawing tools; a
disconnected drawer stalls the turn until the timer expires.
