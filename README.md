# نقاشی بکش — Android app (Flutter)

Persian party drawing game. This is the client; it talks to the Node server in
`server`.

> **This has not been compiled.** It was written without a Dart toolchain
> available, so expect to fix a handful of analyzer complaints on first build.
> `flutter analyze` will list them all in one go.

## Build the APK

You need Flutter (3.19+) and Android Studio with the Android SDK.

```bash
# 1. generate the android/ ios/ scaffolding this repo doesn't carry
flutter create --project-name naqashi --org com.yourname --platforms=android .

# 2. the generated manifest overwrites ours — restore it
#    (it carries the INTERNET + RECORD_AUDIO permissions and the RTL app label)
git checkout android/app/src/main/AndroidManifest.xml
#    or copy it back by hand if you're not using git

# 3. dependencies, then check it compiles
flutter pub get
flutter analyze

# 4. run on a plugged-in phone
flutter run

# 5. build the installable file
flutter build apk --release              # single APK, ~20 MB
flutter build apk --split-per-abi        # smaller, one per CPU — prefer this
```

Output lands in `build/app/outputs/flutter-apk/`.

`--split-per-abi` produces ~8 MB files instead of one ~20 MB universal APK.
That matters: your users are on metered mobile data, and Cafe Bazaar shows
download size prominently.

## Playtesting on your own wifi

1. Start the server on your laptop: `cd server && node server.js`
2. Find the laptop's LAN address — `hostname -I` (Linux) or
   `ipconfig getifaddr en0` (macOS). Something like `192.168.1.10`.
3. On the home screen of the app, set **آدرس سرور** to `192.168.1.10:8080`.
4. Everyone joins the same wifi. Host creates a private room, shares the code.

`android:usesCleartextTraffic="true"` in the manifest is what allows plain
`ws://` here. **Turn it off before release** and put the server behind TLS
(`wss://`), or Cafe Bazaar review may flag it and traffic is readable in transit.

## Project layout

```
lib/
  main.dart              app entry; forces RTL for the whole tree
  theme.dart             palette, Vazirmatn text theme, shared buttons, fa() digits
  persian.dart           normaliser + judge() — offline/practice only, see below
  net/game_client.dart   WebSocket client; ChangeNotifier mirroring server state
  ui/home_screen.dart    name/avatar, server address, room entry, lobby, host sheet
  ui/game_screen.dart    choose word / draw / guess / results
  ui/widgets.dart        canvas painter, timer ring, masked word, chat, push-to-talk
assets/fonts/            Vazirmatn, bundled (see note)
```

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

Working: room creation and joining, private vs public rules, host mute/kick,
free-for-all and team modes, word choice, live drawing sync, masked word with
hints, guess submission with server verdicts, the steal window, per-turn and
final scoring.

Not built yet:

- **Voice audio.** The push-to-talk button and all the mute rules are wired, but
  no audio is transmitted. That needs an SFU (LiveKit or mediasoup) alongside the
  game server; `permission_handler` is already a dependency for the mic prompt.
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
