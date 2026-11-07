'use strict';
// Plays the real app (web build) on several simulated phones against the real
// server and screenshots every screen. Fails loudly if a screen doesn't appear.
//
//   tool/ui_e2e/build_web.sh /tmp/web
//   node tool/ui_e2e/play.cjs /tmp/web /tmp/shots [scale]
//
// Needs Playwright with Chromium (preinstalled in Claude Code cloud sessions).
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const L = require('./lib.cjs');

const ROOT = path.resolve(__dirname, '../..');
const [WEB, OUT, SCALE = '1'] = process.argv.slice(2);
if (!WEB || !OUT) { console.error('usage: play.cjs <web-dir> <out-dir> [scale]'); process.exit(2); }
fs.mkdirSync(OUT, { recursive: true });

const WEB_PORT = 18400, FFA_PORT = 18401, TEAM_PORT = 18402;
const shot = (page, name) => page.screenshot({ path: path.join(OUT, name + '.png') });
const log = (...a) => console.log('•', ...a);

/** First launch: name + avatar, then home. */
async function newPhone(browser, name) {
  const page = await L.openPhone(browser, `http://127.0.0.1:${WEB_PORT}/`, Number(SCALE));
  await L.waitText(page, 'اسمت چیه');
  await L.typeInto(page, 0, name);
  await L.tap(page, 'بزن بریم');
  await L.waitText(page, 'بازی با دوستان');
  await L.sleep(500);
  return page;
}

/** Home → online sheet → create a room, or join one by code. */
async function online(page, port, code) {
  await L.tap(page, 'بازی با دوستان');
  await L.waitText(page, 'ساخت اتاق خصوصی');
  await L.sleep(400);
  await L.typeInto(page, 'last', `127.0.0.1:${port}`);
  if (code) {
    await L.typeInto(page, 0, code);
    await L.tap(page, 'ورود');
  } else {
    await L.tap(page, 'ساخت اتاق خصوصی');
  }
}

const roomCode = async page => (await L.waitText(page, /کد اتاق [A-Z0-9]{5}/)).match(/کد اتاق ([A-Z0-9]{5})/)[1];

async function findDrawer(pages) {
  for (let i = 0; i < 120; i++) {
    for (const p of pages) if ((await L.texts(p)).some(t => t.includes('نوبت توئه'))) return p;
    await L.sleep(150);
  }
  throw new Error('no drawer');
}

async function drawerWord(page) {
  await L.waitText(page, 'داری این رو می‌کشی');
  const all = await L.texts(page);
  const i = all.findIndex(t => t.includes('داری این رو می‌کشی'));
  const merged = all[i].split('\n').map(s => s.trim()).filter(Boolean);
  return merged.length > 1 ? merged[merged.length - 1] : all[i + 1];
}

/** A little house, drawn with the mouse inside the paper. */
async function drawSomething(page, y0 = 330, pauseMid) {
  const strokes = [
    [[120, y0], [120, y0 + 110], [270, y0 + 110], [270, y0], [120, y0]],
    [[110, y0 + 5], [195, y0 - 70], [280, y0 + 5]],
    [[180, y0 + 110], [180, y0 + 60], [210, y0 + 60], [210, y0 + 110]],
  ];
  for (const [si, s] of strokes.entries()) {
    await page.mouse.move(...s[0]);
    await page.mouse.down();
    for (const [pi, p] of s.slice(1).entries()) {
      await page.mouse.move(...p, { steps: 8 });
      if (pauseMid && si === 0 && pi === 1) await pauseMid();
    }
    await page.mouse.up();
    await L.sleep(120);
  }
}

async function guess(page, text) {
  // Tap the board first, as a person tapping back into the box would: Flutter web
  // with the semantics tree on takes one Enter per focus (not an app issue;
  // test/widget_test.dart checks repeated sends on the real widget). Under heavy
  // load a key press can still be lost, so check the box cleared (= sent) and retry.
  for (let attempt = 1; attempt <= 3; attempt++) {
    await page.mouse.click(195, 400);
    await L.sleep(150);
    await L.typeInto(page, 0, text);
    await page.keyboard.press('Enter');
    await L.sleep(300);
    const left = await page.locator('flt-semantics input').first().inputValue().catch(() => '');
    if (left === '') return;
    console.log(`  (guess "${text}" not sent on attempt ${attempt}, retrying)`);
  }
  throw new Error(`could not send guess "${text}"`);
}

(async () => {
  const web = await L.serveStatic(path.resolve(WEB), WEB_PORT);
  const ffa = await L.startGameServer(ROOT, FFA_PORT, { RESULT_PAUSE_MS: '2500' });
  const team = await L.startGameServer(ROOT, TEAM_PORT, { TURN_SECONDS: '6', RESULT_PAUSE_MS: '2500' });
  const browser = await chromium.launch();
  try {
    /* ---------------- first run, home, sheets ---------------- */
    const solo = await L.openPhone(browser, `http://127.0.0.1:${WEB_PORT}/`, Number(SCALE));
    await L.waitText(solo, 'اسمت چیه');
    await L.sleep(700);
    await shot(solo, '01-first-run');
    await L.typeInto(solo, 0, 'نگار');
    await L.tap(solo, 'بزن بریم');
    await L.waitText(solo, 'دورهمی');
    await L.sleep(900);
    await shot(solo, '02-home');
    await L.tap(solo, 'پروفایل');
    await L.waitText(solo, 'بهترین امتیاز');
    await L.sleep(500);
    await shot(solo, '03-profile');
    await solo.keyboard.press('Escape');
    await L.sleep(500);
    await L.tap(solo, 'تنظیمات');
    await L.waitText(solo, 'سرور بازی آنلاین');
    await L.sleep(500);
    await shot(solo, '04-settings');
    await L.tap(solo, 'چطوری بازی کنم');
    await L.waitText(solo, 'یکی می‌کشه');
    await L.sleep(600);
    await shot(solo, '05-how-to-play');
    for (let i = 0; i < 2; i++) { await solo.keyboard.press('Escape'); await L.sleep(500); }
    await L.waitText(solo, 'دورهمی');
    log('home and sheets');

    /* ---------------- offline party mode ---------------- */
    await L.tap(solo, 'دورهمی');
    await L.waitText(solo, 'شروع دورهمی');
    await L.sleep(500);
    await shot(solo, '40-party-setup');
    await L.tap(solo, 'شروع دورهمی');
    for (let t = 0; t < 6; t++) {
      await L.waitText(solo, 'کلمه رو نشونم بده');
      if (t === 0) { await L.sleep(500); await shot(solo, '41-party-pass-phone'); }
      await L.tap(solo, 'کلمه رو نشونم بده');
      await L.waitText(solo, 'آسون');
      if (t === 0) { await L.sleep(500); await shot(solo, '42-party-choose'); }
      await L.tap(solo, 'آسون');
      await L.waitText(solo, 'گرفتن');
      if (t === 0) {
        await drawSomething(solo, 300);
        await L.sleep(300);
        await shot(solo, '43-party-drawing');
        await L.tap(solo, 'گرفتن');
        await L.waitText(solo, 'گرفت!');
        await L.sleep(1300);
        await shot(solo, '44-party-result');
      } else if (t === 1) {
        await L.tap(solo, 'تسلیم');
        await L.waitText(solo, 'بدزد');
        await L.sleep(500);
        await shot(solo, '45-party-steal');
        await L.tap(solo, 'دزدیدن');
        await L.waitText(solo, 'دزدید!');
      } else {
        await L.tap(solo, 'گرفتن');
        await L.waitText(solo, 'گرفت!');
      }
      await L.tap(solo, t < 5 ? 'نوبت بعد' : 'نتیجه');
    }
    await L.waitText(solo, 'یه دست دیگه');
    await L.sleep(2200);
    await shot(solo, '46-party-over');
    log('party game finished');
    // pantomime: same flow, the phone shows only the word and the clock
    await L.tap(solo, 'تنظیمات دورهمی');
    await L.waitText(solo, 'شروع دورهمی');
    await L.tap(solo, 'پانتومیم');
    await L.tap(solo, 'شروع دورهمی');
    await L.tap(solo, 'کلمه رو نشونم بده');
    await L.waitText(solo, 'حرف زدن ممنوع');
    await L.tap(solo, 'آسون');
    await L.waitText(solo, 'ادا دربیار');
    await L.sleep(500);
    await shot(solo, '47-party-mime');
    log('pantomime mode');
    await solo.context().close();   // rendering is software-only here: free the CPU

    /* ---------------- online free-for-all, three phones ---------------- */
    const host = await newPhone(browser, 'پویا');
    await online(host, FFA_PORT);
    const code = await roomCode(host);
    log('room', code);
    const sara = await newPhone(browser, 'سارا');
    await online(sara, FFA_PORT, code);
    const milad = await newPhone(browser, 'میلاد');
    await online(milad, FFA_PORT, code);
    const phones = [host, sara, milad];
    for (const p of phones) await L.waitText(p, 'بازیکن‌ها (۳)');
    await L.sleep(600);
    await shot(host, '10-lobby-host');
    await shot(sara, '11-lobby-guest');

    await L.tap(host, 'شروع بازی');
    for (let turn = 1; turn <= 6; turn++) {
      const drawer = await findDrawer(phones);
      const guessers = phones.filter(p => p !== drawer);
      if (turn === 1) {
        await L.waitText(guessers[0], 'داره کلمه انتخاب می‌کنه');
        await L.sleep(500);
        await shot(drawer, '12-choose-word');
        await shot(guessers[0], '13-waiting-for-drawer');
      }
      await L.tap(drawer, 'آسون');
      const word = await drawerWord(drawer);
      log(`turn ${turn}: word`, word);
      if (turn === 1) {
        await L.waitText(guessers[0], 'داره می‌کشه');
        // screenshot a guesser while the drawer's finger is still down: live ink
        await drawSomething(drawer, 330, async () => {
          await L.sleep(400);
          await shot(guessers[0], '14-guesser-sees-live-ink');
        });
        await L.sleep(400);
        await guess(guessers[0], 'زرافه');
        if ([...word].length >= 2) await guess(guessers[1], word.slice(0, -1));
        await L.sleep(500);
        await shot(drawer, '15-drawing');
        await shot(guessers[1], '16-guessing-near-miss');
        await guess(guessers[0], word);
        await L.waitText(guessers[0], 'حلش کردی');
        await L.sleep(350);
        await shot(guessers[0], '17-solved-celebration');
        await L.sleep(900);
        await guess(guessers[0], 'آفرین!');
        await L.sleep(400);
        await shot(guessers[0], '18-solved');
        await guess(guessers[1], word);
        await L.waitText(host, 'نوبت بعد داره شروع');
        await L.sleep(1200);
        await shot(host, '19-turn-results');
      } else {
        for (const g of guessers) await L.waitText(g, 'داره می‌کشه');
        await L.sleep(600);   // let the screen transition finish, as a person would
        for (const g of guessers) await guess(g, word);
      }
      await L.waitText(host, turn < 6 ? 'نوبت بعد' : 'برد', 20000);
    }
    await L.sleep(2500);
    await shot(host, '20-game-over');
    await shot(sara, '21-game-over-guest');
    await L.tap(host, 'بازی دوباره');
    await L.waitText(sara, 'منتظر میزبان');
    log('free-for-all game finished, play again returned to the lobby');
    for (const p of phones) await p.context().close();   // free the CPU for the next phones

    /* ---------------- team mode, steal window ---------------- */
    const a = await newPhone(browser, 'آرش');
    await online(a, TEAM_PORT);
    const tcode = await roomCode(a);
    const b = await newPhone(browser, 'بهار');
    await online(b, TEAM_PORT, tcode);
    await L.waitText(a, 'بازیکن‌ها (۲)');
    await L.tap(a, 'تیمی');
    await L.waitText(a, 'یکی در میون');
    await L.sleep(500);
    await shot(a, '30-lobby-team');
    await L.tap(a, 'شروع بازی');
    const td = await findDrawer([a, b]);
    const watcher = td === a ? b : a;
    await L.tap(td, 'آسون');
    const tword = await drawerWord(td);
    await drawSomething(td);
    await L.waitText(watcher, 'داره می‌کشه');
    await L.sleep(400);
    await shot(watcher, '31-team-other-side-watches');
    await L.waitText(watcher, 'فرصت دزدیدن', 15000);
    await shot(watcher, '32-steal-window');
    await guess(watcher, tword);
    await L.waitText(watcher, '۷۵ امتیاز', 8000);       // the steal scored
    await L.waitText(a, 'نوبت بعد داره شروع');
    await L.sleep(1200);
    await shot(a, '33-team-results');
    log('team game: steal scored 75');

    /* ---------------- errors ---------------- */
    const lost = await newPhone(browser, 'گم');
    await online(lost, 1);
    await L.waitText(lost, 'به سرور وصل نشد');
    await L.sleep(300);
    await shot(lost, '50-cannot-reach-server');

    team.kill();                               // server goes away mid-game
    await L.waitText(a, 'داریم دوباره وصلت می‌کنیم');
    await L.sleep(300);
    await shot(a, '51-reconnecting');
    log('all screens reached');
  } catch (e) {
    // leave a picture of every open phone, to see what went wrong
    let i = 0;
    for (const ctx of browser.contexts()) for (const pg of ctx.pages()) await pg.screenshot({ path: path.join(OUT, `zz-fail-${i++}.png`) }).catch(() => {});
    throw e;
  } finally {
    await browser.close();
    ffa.kill(); team.kill(); web.close();
  }
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
