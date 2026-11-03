# Handoff — نقاشی بکش

Written 2026-11-03 at the end of a long design/build conversation in Claude.ai (chat), which
could write code and run Node tests but **could not install Flutter/Android SDK or produce an APK**.
Claude Code on the owner's laptop is the first environment that can. This file is the state
of the world; `CLAUDE.md` is the standing rules.

## Goal

Ship an Android APK of a Persian multiplayer drawing/guessing game to Cafe Bazaar and
Myket, and make money from it (rewarded ads + cosmetic IAP). Immediate goal: **get a
compiled, installable APK onto the owner's phone and playtest it with real people over wifi.**

## Verified vs not (be honest about this)

| Thing | Status |
|---|---|
| Server game logic (rooms, turns, scoring, team gating, steal, solver chat gating, host mute/kick rules, drawer-only strokes, turn auto-advance) | **Verified** — `server/test.js`, 29 assertions against real WebSocket clients |
| Persian matcher `judge()` (harakat, tatweel, ZWNJ, digits, alef/yeh/kaf variants, aliases, length-scaled "close") | **Verified** by test run |
| Web prototype UI/feel | Played only in an artifact preview; works |
| Flutter client | **Not compiled.** Structure-checked only (balanced braces, imports resolve). Expect errors. |
| Client ↔ server protocol agreement | **Not exercised.** Written from the README protocol; never run together. |
| GitHub Actions workflow | YAML valid, never run |
| Voice audio | **Not built.** UI + rules only. |
| Billing, ads | **Not built.** |
| Competitor analysis | **Thin** — from search snippets only. See below. |

Two real bugs were found and fixed while preparing this handoff: (1) the server never
advanced to the next turn after results (game froze after turn 1) — fixed and tested;
(2) Flutter code used `Color.withValues` (needs Flutter ≥3.27) while CI pins 3.24 — replaced
with `withOpacity`; and a custom `firstOrNull` extension that would clash with `dart:core` — removed.

## Step 1 — Get a toolchain and build (first session)

Do these in order. Stop and report if a download keeps failing.

1. `git init && git add -A && git commit -m "baseline"` so `flutter create` changes are diffable.
2. Check what exists: `flutter --version`, `java -version`, `adb version`. Install only what's missing.
   Flutter **3.24.x** stable is the pinned version (also in CI). Android SDK: platform 34,
   build-tools 34, cmdline-tools, platform-tools; accept licenses (`flutter doctor --android-licenses`).
3. Enable Windows Developer Mode.
4. Preserve our manifest, generate scaffolding, restore it:
   ```
   copy android\app\src\main\AndroidManifest.xml %TEMP%\OurManifest.xml
   flutter create --project-name naqashi --org ir.naqashi --platforms=android .
   copy %TEMP%\OurManifest.xml android\app\src\main\AndroidManifest.xml
   git diff --stat      # lib/ and pubspec.yaml must be unchanged; if flutter create touched them, restore
   ```
5. `flutter pub get`, then `flutter analyze`. **Fix every error.** Warnings/infos are lower priority.
6. `flutter build apk --release --split-per-abi`. Report the exact path of each APK and its size.

If Google/Maven downloads are blocked or hopeless: tell the owner, and either configure
mirrors (`PUB_HOSTED_URL`, `FLUTTER_STORAGE_BASE_URL`, Gradle repository mirrors) or fall
back to the GitHub Actions workflow (owner pushes the repo, downloads the artifact). Mirror
choices are unverified from here — test before relying on them.

## Step 2 — Playtest over wifi

1. `cd server && npm install && node server.js`
2. Owner finds laptop LAN IP (`ipconfig`), sets it in the app's **آدرس سرور** field (`192.168.x.x:8080`).
3. Windows Firewall must allow inbound TCP 8080 on the private network.
4. Phones on the same wifi. Host taps **ساخت اتاق خصوصی**; others use the code.
5. Debug the first end-to-end run — this is where client/server protocol mismatches will surface.
   Likely suspects: `turn` message field names, `room` phase strings, stroke JSON shape,
   `results` → next-turn transition on the client.

## Step 3 — Close the gap between prototype and app

The web prototype has things the Flutter app lacks. Port, in this order:
1. **Undo + eraser** in the drawing tools.
2. **Live stroke streaming** — currently only completed strokes are sent, so guessers see
   nothing until the drawer lifts their finger. Send throttled point batches while drawing.
3. **Solver state on the client** — after `youSolved`, switch the input to solver-only chat
   (placeholder + "فقط حل‌کننده‌ها" tag) and show 🔒 on solved players' avatars.
4. **Near-miss "نزدیکه!"** is private to the guesser (server sends `scope:'private'`); verify the client renders it.
5. **Save/share drawing** as PNG via the platform share sheet (Telegram/WhatsApp are the main acquisition channel).
6. **Custom word packs** (local, persisted) — server currently uses built-in words only; needs a
   protocol addition so the host can choose a pack.

## Step 4 — Server hardening (before strangers play)

- **Auto-advance exists now; also handle drawer disconnect mid-turn** (turn currently stalls until timer).
- Handle player leaving mid-game (`r.order` still contains them).
- **"Play again"** — after `over`, reset the room to lobby.
- Reconnection grace period.
- Rate limit `guess` and `stroke`; cap stroke payload size.
- Reporting flow (`{t:'report'}`) persisted somewhere a human can review — prerequisite for ever enabling voice in public rooms.
- Expand the word bank (currently ~30 words) and the alias table; this is a content task, not a code one.
- Deploy: a cheap Iran-hosted VPS (low ping to the audience), TLS (`wss://`), process manager.

## Step 5 — Voice (private rooms only)

Needs an SFU beside the game server (LiveKit self-hosted or mediasoup). Rules to enforce
**as media routing**, not UI: drawer silent in team mode; solved players audible only to
solved players; `hostMuted` players audible to nobody; local mute is client-side. Use
`permission_handler` (already a dependency) for the mic prompt. Decide hosting before
choosing — WebRTC from inside Iran has its own reachability problems; verify with real devices.

## Step 6 — Money and release

- **Billing:** Cafe Bazaar in-app billing via the Poolakey library (a Flutter plugin exists; check it is maintained), plus Myket's equivalent. **Not Google Play Billing.**
- **Ads:** Tapsell or Adivery, rewarded video for hints/colour unlocks; at most one interstitial every ~3 rounds.
- **IAP:** avatar sets, brush/colour packs, premium word packs, ad-free pass. **No loot boxes** (Bazaar requires odds disclosure and it invites review trouble).
- Release signing (keystore + `key.properties`), `usesCleartextTraffic="false"`, `wss://`, bump `version:` for every upload, real app icon.
- Content rules: no gambling, no sexual content, nothing politically or religiously sensitive; Persian localisation is mandatory.

## Open decisions for the owner

1. **Opposing team sees the word while watching?** Currently no. Physical Pictionary says yes (watchers heckle and catch cheating). Easy to flip server-side.
2. **Turn length:** 80 s free-for-all / 60 s team are guesses. Tune from playtesting.
3. **Competitor:** see below — owner should install تخته گچی and play before more building.
4. **Hosting + domain** for the server — not yet chosen.

## Competitor note — تخته گچی (low confidence)

The owner reported a game called **تخته گچی** on Cafe Bazaar (package `com.takhtegachi`) with ~42,000 users.
From search snippets only (never played or installed by the previous assistant, and results may blend
several similarly-named apps, including a Myket "چارتخته (تخته گچی)" variant): it appears to be a
chalkboard-themed group guessing game dating back to ≥2018; one description says guessers pick
from provided options rather than typing; chat may be preset phrases only; one variant showed
~2.0/5 from ~40 Myket reviews with "bring back the old version" complaints. **None of this is
confirmed.** The owner should install it and check: free-text vs multiple-choice guessing; whether
players draw live; voice; chat; teams; monetisation; current rating and recent reviews; drawing feel.
Intended differentiators (if the above holds): free-text Persian guessing with real normalisation,
live player drawing, moderated free chat, private-room voice, team mode.

## Session log

_Claude Code: append a dated entry here before ending every session — what you did, what's
broken, what's next. The owner has about an hour a night at the laptop._

- 2026-11-03 (Claude.ai chat): project assembled; server turn-advance bug and two Flutter API issues fixed; nothing built yet.
