# First wifi playtest — نقاشی بکش

About 20 minutes of setup the first time, 2 minutes after that. You need: the Windows laptop, 2–4
Android phones, and one wifi network they are all on.

Everything is on one page: **https://github.com/AdmEve/game2/releases/tag/android-latest**
(it always holds the newest build).

## 1. The laptop runs the game server

1. **Node.js, once.** Download the Windows Installer (LTS) from https://nodejs.org and install it with
   the defaults. If nodejs.org is slow from Iran, the same installers are mirrored at
   https://npmmirror.com/mirrors/node/ (pick the newest `v22.x` folder → `node-v22.x.x-x64.msi`).
   Not tested from Iran — use whichever downloads.
2. From the release page, download **naqashi-server.js** (into `Downloads`).
3. Open PowerShell and run:
   ```powershell
   cd $HOME\Downloads
   node naqashi-server.js
   ```
   It prints something like:
   ```
   Type this into «آدرس سرور» on each phone (same wifi as this computer):
       192.168.1.23:8080
   ```
   If it lists several addresses, the one starting `192.168.` is almost always the wifi one.
   **Leave this window open** while you play.
4. **Firewall.** The first time, Windows asks whether Node.js may use the network: tick **Private
   networks** and press **Allow**. If no phone can connect later, run this once in an
   *administrator* PowerShell:
   ```powershell
   New-NetFirewallRule -DisplayName "Naqashi 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Private
   ```
   and make sure Windows treats your wifi as private:
   ```powershell
   Get-NetConnectionProfile
   ```
   If it says `NetworkCategory : Public`, run (with the name it shows instead of `Wi-Fi` if different):
   ```powershell
   Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
   ```

## 2. The phones install the app

1. On each phone, open the release page and tap **Naqashi-arm64.apk** (8.8 MB). If Android says the
   app is not compatible, use **Naqashi-arm32.apk** instead.
2. Android asks to allow installing from the browser: allow it, install.
3. Until a signing key is set up (see HANDOFF.md), every new build is signed with a different
   temporary key: **uninstall the old one before installing a new build**, or Android says
   "App not installed".

## 3. Play

1. Every phone: type a name, pick an avatar, and put the laptop's address (e.g. `192.168.1.23:8080`)
   in **آدرس سرور**. The app remembers it.
2. One phone taps **ساخت اتاق خصوصی** and reads out the 5-letter code.
3. The others tap **با کد اتاق وارد شو** and type the code.
4. Host picks **همه با هم** or **تیمی** and taps **شروع بازی**.

**"به سرور وصل نشد"** means the phone can't reach the laptop: check the address, that the server window
is still open, the firewall step, and that the phone is on the same wifi (not mobile data, not a
"guest" network — guest networks usually block phones from reaching the laptop).

## What to try, and what to tell Claude next session

Write down anything odd; a photo of the phone screen helps. Specifically:

- [ ] Installs and opens on every phone? Phone models and Android versions?
- [ ] Persian text and avatars look right? Anything cut off, overlapping, or in the wrong direction?
- [ ] **Drawing feel:** smooth or laggy? Lines where your finger was? (Known: others only see a line
      after the drawer lifts their finger. Live drawing is the next thing to build.)
- [ ] **Typing guesses** with the Persian keyboard: are right answers accepted when typed naturally
      (with or without spaces / half-spaces, ي vs ی)? Any right answer rejected? Any wrong one accepted?
- [ ] Does «نزدیکه» (near miss) show only to the person who typed it?
- [ ] **Team mode with 4 people:** does the other team get the 10-second steal when nobody guesses?
- [ ] Turn length: 80 s (everyone) / 60 s (teams) — too long, too short?
- [ ] Someone closes the app or turns off wifi mid-turn: does the game carry on for the others?
- [ ] Someone switches to another app for a few seconds and comes back: still in the game?
      (Expected to drop out — reconnection isn't built yet. Tell us how often this bites.)
- [ ] Words: too easy, too hard, unfamiliar? Any word that shouldn't be in the game?
- [ ] The question from HANDOFF.md: should the **other team see the word** while watching (like
      real Pictionary, so they can heckle)? Ask your players.
- [ ] What did people *want* to do that they couldn't?

## Not built yet (don't be surprised)

Live drawing while the finger moves, undo and eraser buttons (the cream colour acts as an eraser),
voice chat, sharing a drawing, reconnecting after a drop, "play again" (go back home and make a new
room), sounds.
