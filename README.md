# نقاشی بکش — Android app (Flutter)

Persian party drawing game. This is the client; it talks to the Node server in
`server`.

## Get the APK

You don't need to build anything: every push to GitHub builds the app and puts the newest APKs
on **https://github.com/AdmEve/game2/releases/tag/android-latest**. Open that page on the phone and
tap `Naqashi-arm64.apk`. See `PLAYTEST.md` for a wifi game with friends.

## Build it yourself

Flutter **3.47.9**, a JDK 17+ and the Android SDK. The Android project is committed, so:

```bash
flutter pub get
flutter analyze
flutter test                                   # needs `npm install` in server/ first
flutter run                                    # plugged-in phone
flutter build apk --release --split-per-abi    # ~8–9 MB per CPU type
```

Output lands in `build/app/outputs/flutter-apk/`. Release builds use the key in
`android/key.properties` when it exists (CI writes it), otherwise the debug key.

## Playtesting on your own wifi

Step by step for Windows: `PLAYTEST.md`. In short:

1. Start the server on your laptop: `node naqashi-server.js` (from the release page) or
   `cd server && npm install && node server.js`. It prints the LAN address to use.
2. On the home screen of the app, set **آدرس سرور** to that address, e.g. `192.168.1.10:8080`.
3. Everyone joins the same wifi. Host creates a private room, shares the code.

`android:usesCleartextTraffic="true"` in the manifest is what allows plain
`ws://` here. **Turn it off before release** and put the server behind TLS
(`wss://`), or Cafe Bazaar review may flag it and traffic is readable in transit.

## Project layout

See CLAUDE.md → "App layout". Assets: `assets/fonts/` (Vazirmatn, bundled — see note),
`assets/sfx/` (generated sounds), `assets/words/fa.json` (word bank shared with the server).

### Why the font is bundled

`google_fonts` fetches at runtime from Google's servers, which are unreliable
or blocked for Iranian users. A missing font would fall back to a Latin face and
render Persian badly. The six weights ship inside the APK instead — ~740 KB, and
worth every byte.

### Why `persian.dart` duplicates the server's matcher

It doesn't decide anything. Guess verdicts come from the server, which is the
only place that holds the answer. This copy exists for an offline practice mode
and for instant local feedback. **Never** score a networked game with it — that
would put the answer back on the device and make cheating trivial.

## State of things

Working (verified by `test/protocol_test.dart` against the real server, and by
`tool/ui_e2e` playing the web build): room creation and joining, private vs
public rules, host kick, free-for-all and team modes, word choice, drawing sync
(completed strokes), masked word with hints, guess submission with server
verdicts, near-miss and solver-only chat, the steal window, per-turn and final
scoring, players leaving mid-game, connection errors.

Not built yet:

- **Voice audio.** The push-to-talk button and the mute rules exist but are
  hidden (`kVoiceBuilt = false`) because no audio is transmitted. That needs an
  SFU (LiveKit or mediasoup) alongside the game server.
- **Cafe Bazaar billing** (`com.farsitel.bazaar` IAB) and **Tapsell ads.** Both
  ship as Android libraries and need a small platform channel or their Flutter
  plugins.
- **Reconnection.** Dropping out of a game currently means leaving it.
- **Sound effects and haptics.**
- **App icon.** `flutter create` leaves the default Flutter logo.

## Before submitting to Cafe Bazaar

- Sign the release build (`android/key.properties` + a keystore) — an unsigned
  or debug-signed APK is rejected.
- Turn off cleartext traffic, move to `wss://`.
- Voice chat with a young audience needs a visible reporting path and a
  moderation contact; have that ready before enabling voice in public rooms.
- Bump `version:` in `pubspec.yaml` for every upload — Bazaar rejects a repeated
  version code.
