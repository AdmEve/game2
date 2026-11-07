# نقاشی بکش (Naqashi Bekesh) — project context for Claude Code

A Persian-language multiplayer party drawing-and-guessing game for Android, aimed at
the Iranian market and distributed through **Cafe Bazaar** and **Myket**. One player
draws a word, the others guess it. Free-for-all and team modes. Owner is building it
solo and wants to make money from it.

**Read `HANDOFF.md` first** for current status, what is verified vs not, and the task order.

## What exists

| Path | What | State |
|---|---|---|
| `lib/`, `pubspec.yaml`, `android/`, `assets/` | Flutter Android client (Flutter 3.47.9) | **Builds.** Analyzer clean. Not yet tried on a real phone. |
| `server/` | Node + `ws` authoritative game server | **Tested.** `cd server && npm install && node test.js` → 76 passing. |
| `assets/words/fa.json` | The word bank (496 words, 3 tiers, aliases) — read by the server *and* offline mode | Validated by tests. |
| `test/` | widget tests, `party_rules_test.dart`, `protocol_test.dart` (app client vs real server) | Passing. Protocol test needs `npm install` in `server/`. |
| `docs/QUALITY_PLAN.md` | The plan: 18 aspects of the game, done (✅) and next (⏭) | Current. Work from it. |
| `tool/sfx/make_sfx.py`, `tool/icon/make_icon.py` | Generate `assets/sfx/*.wav` and the launcher icons/splash/store icon | Re-run after editing; output is committed. |
| `tool/ui_e2e/` | Web build of the app driven by Playwright on simulated phones, screenshots every screen | Passing. Cloud sessions only (needs Playwright + Chromium). |
| `prototype/naqashi.html` | Single-file web prototype (bots, no networking) | Working. Reference for UI feel and rules only. Not connected to the server. |
| `.github/workflows/build.yml` | CI: tests, builds APKs, publishes release `android-latest` | **Green.** This is how APKs reach the owner. |
| `PLAYTEST.md` | Owner's wifi playtest guide + feedback checklist | Current. |
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
  `start ms-settings:developers`. (Only if Flutter is ever installed on the laptop: so far all
  builds happen in Claude Code cloud sessions and GitHub CI, and the owner needs only Node.)
- **Claude Code cloud sessions** can install Flutter (`/opt/flutter`) and the Android SDK
  (`/opt/android-sdk`) and build here, but nothing persists between sessions: reinstall from
  `storage.googleapis.com/flutter_infra_release` and `dl.google.com`. Maven Central returns HTTP 429 to
  these machines; add a user-level `~/.gradle/init.d/` script that rewrites
  `https://repo.maven.apache.org/maven2` to `https://maven-central.storage-download.googleapis.com/maven2/`
  (in `beforeSettings` and `allprojects`, repositories `configureEach`). No KVM, so no emulator:
  verify with `flutter test` and `tool/ui_e2e/`.

## App layout

```
lib/main.dart            loads Settings, sounds; first-run screen or home
lib/theme.dart           palette C, fa(), Pressable, GameButton, Panel, ChoiceChipX
lib/config.dart          kVoiceBuilt
lib/core/                settings (prefs + stats), progress (XP/levels/unlocks), sfx (sounds + haptics), words
lib/draw/board.dart      Stroke, BoardModel (cached picture + live stroke), DrawingSurface, StrokeSender, PNG export
lib/net/game_client.dart WebSocket client: protocol, reconnection, events stream for UI effects
lib/party/party_rules.dart  offline party mode rules (pure, tested)
lib/ui/                  home, sheets (onboarding/profile/settings/how-to/online), fx (confetti, toasts,
                         count-up, doodles, logo), widgets (timer, mask, chat, player strip, tool tray, guess bar)
lib/ui/online/           lobby, game screen (choose/wait/draw/guess/results/podium)
lib/ui/party/            دورهمی setup and game screens
```

## Commands

```bash
# server
cd server && npm install && node test.js        # must stay green
node server.js                                  # listens :8080

cd server && npm run bundle                     # dist/naqashi-server.js, single file, needs only Node

# app
flutter pub get
flutter analyze                                 # must say "No issues found"
flutter test                                    # widget + protocol tests (needs server/node_modules)
flutter run                                     # plugged-in phone
flutter build apk --release --split-per-abi     # output: build/app/outputs/flutter-apk/

# UI playthrough on simulated phones (cloud session)
tool/ui_e2e/build_web.sh /tmp/web && node tool/ui_e2e/play.cjs /tmp/web /tmp/shots 2
```

## Architecture rules — do not break these

1. **The server is authoritative.** The answer word lives only in server memory. Guessers
   receive a letter *mask*, never the word. Only the drawer receives it. The `solved`
   broadcast names the solver and carries no word. `youSolved` reveals it only to the solver.
2. **`judge()` runs on the server** (`server/game.js`). `lib/persian.dart` is a copy for
   offline practice only — never score a networked game with it.
3. **Voice policy:** voice only in **private** rooms (invite code). Public matchmaking is
   **text-only** until a reporting flow exists. Host can mute-for-all and kick in private rooms.
   The drawer's mic is disabled in team mode (they could say the word). Until audio exists,
   `kVoiceBuilt = false` (`lib/config.dart`) hides all voice UI — never show voice controls that do nothing.
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
- Protocol changes: update `test/protocol_test.dart` too, so the app and server stay in agreement.
- The repo is **public**: never commit keystores, `key.properties` or other secrets.
- Prefer small, verifiable steps. Say plainly what you verified and what you did not.
- Do not claim an APK exists unless you built it and can name the file path.

## Known gaps (also tracked in HANDOFF.md)

Not tried on a real phone yet; sounds never heard by a person; no voice transport; no billing/ads;
no public server (online needs a LAN server); temporary signing key per CI build. Everything else
planned is in `docs/QUALITY_PLAN.md` (⏭).
