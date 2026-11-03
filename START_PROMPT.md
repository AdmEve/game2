# Starting a new Claude Code session on this project

Paste this as the first message (cloud session at claude.ai/code with the `AdmEve/game2` repo, or
Claude Code on the laptop):

---

Read CLAUDE.md and HANDOFF.md fully before doing anything, including the newest Session log entry.

Here are my playtest notes from PLAYTEST.md: <paste them, or say "no playtest yet">

Goal for this session: <e.g. "fix what the playtest found, then live stroke streaming + undo/eraser">.

Keep `flutter analyze`, `flutter test` and `server/test.js` green, push to the work branch so CI
publishes a new build to the android-latest release, and append a dated Session log entry to
HANDOFF.md before you stop. Tell me plainly what you verified and what you didn't.

---

The original first-session prompt (install Flutter on the Windows laptop) is obsolete: builds now run
in Claude Code cloud sessions and GitHub Actions, and the laptop only needs Node for the playtest server.
