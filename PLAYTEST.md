# Playtest guide — نقاشی بکش

Everything is on one page: **https://github.com/AdmEve/game2/releases/tag/android-latest**
(it always holds the newest build).

## 1. Install on the phones

1. On each phone, open the release page and tap **Naqashi-arm64.apk** (~9 MB). If Android says the
   app is not compatible, use **Naqashi-arm32.apk** instead.
2. Allow installing from the browser when Android asks, then install.
3. Until a signing key is set up (see HANDOFF.md), every new build is signed with a different
   temporary key: **uninstall the old one before installing a new build**, or Android says
   "App not installed".

First launch asks for a name and an avatar. That's it.

## 2. Start with دورهمی — no setup at all

One phone, no internet, no server. Tap **دورهمی**, name the two teams, pick **نقاشی** (draw) or
**پانتومیم** (act it out), and pass the phone around. The drawer taps **گرفتن!** when their team
shouts the right answer, or **تسلیم** to give up — then the other team gets 10 seconds to steal.

This is the best first test: it needs nothing but people.

## 3. Online: every player on their own phone

### The laptop runs the game server

1. **Node.js, once.** Download the Windows Installer (LTS) from https://nodejs.org and install it with
   the defaults. If nodejs.org is slow from Iran, the same installers are mirrored at
   https://npmmirror.com/mirrors/node/ (newest `v22.x` folder → `node-v22.x.x-x64.msi`).
   Not tested from Iran — use whichever downloads.
2. From the release page, download **naqashi-server.js** (into `Downloads`).
3. Open PowerShell and run:
   ```powershell
   cd $HOME\Downloads
   node naqashi-server.js
   ```
   It prints the address to type into the app, e.g. `192.168.1.23:8080` (the one starting
   `192.168.` is almost always the wifi one). **Leave this window open** while you play.
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
   If it says `NetworkCategory : Public`:
   ```powershell
   Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
   ```

### The phones

1. Tap **بازی با دوستان**. Put the laptop's address in **آدرس سرور** at the bottom (remembered after).
2. One phone taps **ساخت اتاق خصوصی** and taps **بفرست** to send the code (or reads it out).
3. The others type the code and tap **ورود**.
4. The host picks the mode, rounds and turn length, then **شروع بازی**.

**"به سرور وصل نشد"** means the phone can't reach the laptop: check the address, that the server window
is still open, the firewall step, and that the phone is on the same wifi (not mobile data, not a
"guest" network).

## What to try, and what to tell Claude next session

Write down anything odd; a screenshot helps. Specifically:

- [ ] Installs and opens on every phone? Phone models and Android versions? Icon looks right?
- [ ] **Sound and vibration:** do they feel good or annoying? Any sound too loud/quiet? (Both can be
      turned off in ⚙️.)
- [ ] **Drawing feel:** smooth? Does the ink appear on the other phones *while* you draw?
      Undo (↩️), eraser (🧽), clear (🗑️ twice)?
- [ ] **Typing guesses** with the Persian keyboard: are right answers accepted when typed naturally
      (with or without spaces / half-spaces, ي vs ی, «خونه» for «خانه»)? Any right answer rejected?
      Does the keyboard stay open between guesses?
- [ ] Does «نزدیکه» (near miss) show only to the person who typed it?
- [ ] **Team mode with 4 people:** does the other team get the 10-second steal when nobody guesses?
- [ ] **Switch to another app for 10 seconds, then come back** mid-game: you should be put back
      into the game («دوباره وصل شدی»). Same with turning wifi off and on quickly.
- [ ] **بازی دوباره** at the end keeps everyone together?
- [ ] **Share a drawing** from the results screen (📤) to Telegram/WhatsApp: does the picture look good?
- [ ] Turn length and rounds: what did people choose and like?
- [ ] Words: too easy, too hard, unfamiliar? Any word that shouldn't be in the game? (Note it.)
- [ ] دورهمی: did the pass-the-phone flow make sense without explanation? Draw or pantomime more fun?
- [ ] The question from HANDOFF.md: should the **other team see the word** while watching (like
      real Pictionary, so they can heckle)? Ask your players.
- [ ] What did people *want* to do that they couldn't?

## Not built yet (don't be surprised)

Voice chat, a public server (online play needs the laptop on the same wifi), a fill/bucket tool,
music, achievements, in-app purchases and ads.
