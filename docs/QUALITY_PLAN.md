# Quality plan — making نقاشی بکش the best game in its category

"AAA" means a studio budget we don't have. What we *can* match is the thing players actually
judge a party drawing game on: does it feel great in the hand, does it look and sound like one
confident product, is there always something to play, and do people come back and bring friends.
This plan lists the aspects every game has, where we stand on each, what "best in class" means
for this game, and what ships in which pass.

Status key: ✅ done · ⏭ later pass · 🧑 needs the owner

**Pass 1 (2026-11-07) shipped everything marked ✅.** The "Now" rows describe the game before that pass.

## 1. Core loop and rules

Draw → guess → score → next drawer. Proven loop (Pictionary, Gartic, skribbl).

| | |
|---|---|
| Now | Solid, server-authoritative, tested: FFA + teams + steal, hints, near-miss, solver chat. |
| Best in class | Every turn has tension (timer, hints, steal) and every player is busy (drawer draws, team guesses, other team heckles or steals). Host can tune length. Nobody waits with nothing to do. |
| Plan | ✅ host chooses rounds and turn length · ✅ "play again" keeps the group together · ⏭ harder words worth more (rule change, owner to approve) · ⏭ opposing team sees the word (owner decision, HANDOFF) |

## 2. Game feel ("juice") — the most important aspect for this genre

| | |
|---|---|
| Now | Guessers see nothing until the drawer lifts their finger. Lines are jagged polylines. No feedback when you solve. |
| Best in class | Ink appears on every phone as it is drawn. Lines are smooth. A correct guess *feels* like a win: sound, haptic, burst, score flying in. The last 10 seconds tick. Results count up. The winner gets a podium. |
| Plan | ✅ live stroke streaming (batched every ~40 ms) · ✅ curve smoothing · ✅ confetti, haptics, animated score count-up, timer pulse, letter-reveal pop · ✅ podium game-over screen |

## 3. Controls and tools

| | |
|---|---|
| Now | 9 colours, 4 sizes, clear, and the paper colour as an improvised eraser. |
| Best in class | Undo is one tap and never loses work. A real eraser. Big thumb-sized targets. The canvas never scrolls or zooms by accident. |
| Plan | ✅ undo (server-synced) · ✅ eraser tool · ✅ redesigned tool tray · ⏭ fill bucket · ⏭ stroke opacity / marker |

## 4. Visual design and art direction

| | |
|---|---|
| Now | A good palette (lâjvard, firuzeh, saffron, cream paper) applied flatly; default Flutter app icon. |
| Best in class | One recognisable identity everywhere — icon, splash, home, in-game — that feels Iranian without cliché. Motion everywhere: nothing pops in without easing. |
| Plan | ✅ custom app icon (adaptive) + splash in brand colours · ✅ home with animated doodle background and a hand-lettered-feel logo lockup · ✅ consistent cards, chips, buttons, page transitions · ⏭ illustrated avatars (replace emoji) · ⏭ seasonal themes (Yalda, Nowruz) |

## 5. Audio

| | |
|---|---|
| Now | Silent. |
| Best in class | Every action has a small, pleasant, recognisable sound. A sonic identity (santur pluck) ties it together. Sound and haptics can each be turned off. |
| Plan | ✅ original SFX set synthesised from scratch (plucked-string "santur" timbre, no licensing issues): tap, correct, near-miss, tick, time-up, turn start, steal, win · ✅ settings toggles · ⏭ menu music loop |

## 6. UI / UX and flow

| | |
|---|---|
| Now | Raw server IP on the home screen; Android back exits a game without asking; no settings. |
| Best in class | Two taps from launch to playing. Technical details hidden. Every state explained (waiting, reconnecting, kicked). Back never loses a game by accident. |
| Plan | ✅ home rebuilt around modes · ✅ settings sheet (sound, haptics, server address moved here) · ✅ confirm before leaving a game · ✅ player strip with scores, drawer ✏️ and solved 🔒 in-game · ✅ "X guessed it!" toasts · ✅ lobby invite via share sheet |

## 7. Onboarding

| | |
|---|---|
| Now | None. |
| Best in class | First launch asks only for a name and avatar; rules are learned by playing, with a short illustrated how-to for those who want it. |
| Plan | ✅ first-run name/avatar sheet · ✅ how-to-play cards · ⏭ interactive first turn |

## 8. Always something to play (modes and offline)

The biggest gap: a party game with nobody online is an uninstall. And there is no public server yet.

| | |
|---|---|
| Now | Online only, needs a laptop server on the same wifi. |
| Best in class | Works at a family gathering with one phone and no internet, *and* online with friends. |
| Plan | ✅ **دورهمی mode: pass-and-play on one phone, fully offline**, two teams, draw mode and پانتومیم (act-it-out) mode, same scoring and steal rules · ⏭ public server so online works anywhere 🧑 (hosting) · ⏭ practice mode with the offline judge |

## 9. Multiplayer and network quality

| | |
|---|---|
| Now | A dropped connection is the end of your game. No rate limits. |
| Best in class | A wifi blip or switching apps for a moment costs nothing. Abuse can't flood a room. |
| Plan | ✅ reconnection: 30 s grace, automatic resume with full state · ✅ rate limits on strokes and guesses · ⏭ public deployment with `wss://` 🧑 |

## 10. Content

| | |
|---|---|
| Now | ~30 words. A word repeats within days of play. |
| Best in class | Hundreds of fair, drawable, culturally familiar words in three difficulties and categories, with the spellings people actually type. |
| Plan | ✅ one shared word bank (`assets/words/fa.json`) for the server and offline mode, ~400 words, 3 tiers, categories, aliases · ✅ recent words not repeated across offline games · ⏭ themed packs (food, Iran, cinema) as IAP |

## 11. Progression and retention

| | |
|---|---|
| Now | Nothing persists between games. |
| Best in class | Every game moves you forward a little: XP, levels, unlocks, personal stats. |
| Plan | ✅ XP and levels (online and offline), stats page, avatars unlocked by level · ⏭ achievements · ⏭ daily word challenge |

## 12. Social and virality

| | |
|---|---|
| Now | A room code you read out loud. |
| Best in class | Every great drawing is one tap from Telegram/WhatsApp with the game's name on it; invites are a link-like message. |
| Plan | ✅ share drawing as PNG with a watermark · ✅ share invite text with the room code · ⏭ deep links that open the room |

## 13. Monetisation (design now, build when accounts exist)

| | |
|---|---|
| Plan | ⏭🧑 Cafe Bazaar billing (Poolakey) + Myket: ad-free pass, avatar sets, brush packs, word packs. Rewarded video (Tapsell/Adivery) for an extra hint. Never pay-to-win, no loot boxes. Level unlocks (§11) are the hook IAP plugs into. |

## 14. Accessibility and localisation

| | |
|---|---|
| Now | Persian RTL throughout; fixed font sizes. |
| Best in class | Readable on small, cheap phones; honours system text size within limits; no information by colour alone. |
| Plan | ✅ text scale clamped to a safe range · ✅ team identity by name + colour, solved by icon + colour · ⏭ left-handed tool tray option |

## 15. Performance and technical quality

| | |
|---|---|
| Now | Every stroke repainted every frame; 8.8 MB APK. |
| Best in class | 60 fps drawing on a cheap 2019 phone; small download; instant start. |
| Plan | ✅ finished strokes cached as a picture, only the live stroke repaints · ✅ keep the APK small (sounds generated compactly) · ⏭ crash reporting that works in Iran (self-hosted) |

## 16. Safety and moderation

| | |
|---|---|
| Plan | ✅ host kick, private-only voice, solver chat gating · ⏭ Persian chat filter · ⏭ report flow (prerequisite for public voice) |

## 17. Store presence

| | |
|---|---|
| Plan | ✅ icon (`store/icon-512.png`) · ⏭ Persian listing, screenshots from `tool/ui_e2e`, privacy policy 🧑 |

## 18. Quality assurance

| | |
|---|---|
| Now | 45 server tests, protocol test, headless UI playthrough. |
| Plan | ✅ tests for every new server rule and protocol message, unit tests for offline-mode rules, UI playthrough extended to new screens · 🧑 real-phone playtests (`PLAYTEST.md`) |
