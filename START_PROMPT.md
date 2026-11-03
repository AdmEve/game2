# Paste this as your first message to Claude Code

Open PowerShell, `cd` into this unzipped folder, then run Claude Code from there:

```powershell
cd Documents\naqashi_project
& "$env:USERPROFILE\.local\bin\claude.exe"
```

Answer **Yes, I trust this folder** (you are inside the project, not your whole user directory).
Approve the install steps when it asks.

---

Read CLAUDE.md and HANDOFF.md fully before doing anything.

Goal for this session: produce an installable release APK of this Flutter app.

Follow "Step 1" in HANDOFF.md exactly. In short: git baseline; check which of Flutter 3.24.x, a JDK
and the Android SDK are already installed and install only what is missing; enable Windows Developer
Mode; preserve android/app/src/main/AndroidManifest.xml across `flutter create --platforms=android .`;
`flutter pub get`; `flutter analyze` and fix every error; `flutter build apk --release --split-per-abi`.

The Dart code has never been compiled, so expect errors — fix them yourself and keep looping until the
build succeeds. Do not change game rules or the architecture rules in CLAUDE.md to make errors go away;
if a fix would require that, stop and ask me.

I am in Iran and can only be at this laptop for about an hour a night. If a download keeps stalling,
tell me plainly and suggest a mirror or the GitHub Actions route instead of retrying the same
multi-GB download. Run long downloads in the background.

Before you stop, append a dated entry to the "Session log" in HANDOFF.md: what you did, what is broken,
what is next. At the end, tell me the exact path and size of each APK, or exactly where the build is stuck.
