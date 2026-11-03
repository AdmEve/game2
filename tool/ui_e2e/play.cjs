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

/** Home screen → private room or join by code. Returns the page. */
async function enter(browser, name, port, code) {
  const page = await L.openPhone(browser, `http://127.0.0.1:${WEB_PORT}/`, Number(SCALE));
  await L.typeInto(page, 0, name);
  await L.typeInto(page, 1, `127.0.0.1:${port}`);
  if (!code) {
    await L.tap(page, 'ساخت اتاق خصوصی');
  } else {
    await L.tap(page, 'با کد اتاق وارد شو');
    await L.waitText(page, 'کد اتاق');
    await L.typeInto(page, 'last', code);
    await L.tap(page, 'برو');
  }
  return page;
}

async function roomCode(page) {
  return L.waitText(page, /^[A-Z0-9]{5}$/);
}

/** Which page is offered words this turn. */
async function findDrawer(pages) {
  for (let i = 0; i < 100; i++) {
    for (const p of pages) if ((await L.texts(p)).some(t => t.includes('نوبت توئه'))) return p;
    await L.sleep(150);
  }
  throw new Error('no drawer');
}

/** The word on the drawer's screen. */
async function drawerWord(page) {
  await L.waitText(page, 'داری این رو می‌کشی');
  const all = await L.texts(page);
  const i = all.findIndex(t => t.includes('داری این رو می‌کشی'));
  // the label and the word may be merged into one node, or be siblings
  const merged = all[i].split('\n').map(s => s.trim()).filter(Boolean);
  return merged.length > 1 ? merged[merged.length - 1] : all[i + 1];
}

async function drawSomething(page) {
  // a house: walls, roof, door; inside the paper area
  const pts = [
    [[120, 360], [120, 470], [270, 470], [270, 360], [120, 360]],
    [[110, 365], [195, 290], [280, 365]],
    [[180, 470], [180, 420], [210, 420], [210, 470]],
  ];
  for (const s of pts) {
    await page.mouse.move(...s[0]);
    await page.mouse.down();
    for (const p of s.slice(1)) await page.mouse.move(...p, { steps: 8 });
    await page.mouse.up();
    await L.sleep(120);
  }
}

async function guess(page, text) {
  await L.typeInto(page, 0, text);
  await page.keyboard.press('Enter');
  await L.sleep(250);
}

(async () => {
  const web = await L.serveStatic(path.resolve(WEB), WEB_PORT);
  const ffa = await L.startGameServer(ROOT, FFA_PORT, { RESULT_PAUSE_MS: '2500' });
  const team = await L.startGameServer(ROOT, TEAM_PORT, { TURN_SECONDS: '6', RESULT_PAUSE_MS: '2500' });
  const browser = await chromium.launch();
  try {
    /* ---------------- free-for-all, three phones ---------------- */
    const host = await enter(browser, 'پویا', FFA_PORT);
    const code = await roomCode(host);
    log('room', code);
    const sara = await enter(browser, 'سارا', FFA_PORT, code);
    const milad = await enter(browser, 'میلاد', FFA_PORT, code);
    const phones = [host, sara, milad];
    for (const p of phones) await L.waitText(p, 'میلاد');
    await shot(host, '01-lobby-host');
    await shot(sara, '02-lobby-guest');

    await L.tap(host, 'شروع بازی');
    for (let turn = 1; turn <= 6; turn++) {
      const drawer = await findDrawer(phones);
      const guessers = phones.filter(p => p !== drawer);
      if (turn === 1) {
        await L.waitText(guessers[0], 'داره کلمه انتخاب می‌کنه');
        await shot(drawer, '03-choose-word');
        await shot(guessers[0], '04-waiting-for-drawer');
      }
      await L.tap(drawer, 'آسون');
      const word = await drawerWord(drawer);
      log(`turn ${turn}: word`, word);
      if (turn === 1) {
        await drawSomething(drawer);
        await L.waitText(guessers[0], 'داره می‌کشه');
        await L.sleep(400);
        await guess(guessers[0], 'زرافه');
        if ([...word].length >= 2) await guess(guessers[1], word.slice(0, -1));
        await L.sleep(400);
        await shot(drawer, '05-drawing');
        await shot(guessers[1], '06-guessing-near-miss');
        await guess(guessers[0], word);
        await L.waitText(guessers[0], 'حلش کردی');
        await guess(guessers[0], 'آفرین، خوب کشیدی!');
        await L.sleep(400);
        await shot(guessers[0], '07-solved');
        await shot(drawer, '08-drawer-sees-solver-chat');
        await guess(guessers[1], word);
        await L.waitText(host, 'نوبت بعد داره شروع');
        await shot(host, '09-turn-results');
      } else {
        for (const g of guessers) await guess(g, word);
      }
      await L.waitText(host, turn < 6 ? 'نوبت بعد' : 'برنده', 20000);
    }
    await shot(host, '10-game-over');
    log('free-for-all game finished');

    /* ---------------- team mode, steal window ---------------- */
    const a = await enter(browser, 'آرش', TEAM_PORT);
    const tcode = await roomCode(a);
    const b = await enter(browser, 'بهار', TEAM_PORT, tcode);
    await L.waitText(a, 'بهار');
    await L.tap(a, 'تیمی');
    await L.waitText(b, 'قرمز');
    await shot(a, '11-lobby-team');
    await L.tap(a, 'شروع بازی');
    const td = await findDrawer([a, b]);
    const watcher = td === a ? b : a;
    await L.tap(td, 'آسون');
    const tword = await drawerWord(td);
    await drawSomething(td);
    await L.waitText(watcher, 'داره می‌کشه');
    await L.sleep(400);
    await shot(watcher, '12-team-other-side-watches');
    await L.waitText(watcher, 'فرصت دزدیدن', 15000);
    await L.sleep(300);
    await shot(watcher, '13-steal-window');
    await guess(watcher, tword);
    await L.waitText(a, 'نوبت بعد داره شروع');
    await shot(a, '14-team-results');
    log('team game: steal worked');

    /* ---------------- errors ---------------- */
    const lost = await L.openPhone(browser, `http://127.0.0.1:${WEB_PORT}/`, Number(SCALE));
    await L.typeInto(lost, 1, '127.0.0.1:1');
    await L.tap(lost, 'ساخت اتاق خصوصی');
    await L.waitText(lost, 'به سرور وصل نشد');
    await shot(lost, '15-cannot-reach-server');

    team.kill();                               // server goes away mid-game
    await L.waitText(a, 'از بازی بیرون اومدی');
    await shot(a, '16-connection-lost');
    log('all screens reached');
  } finally {
    await browser.close();
    ffa.kill(); team.kill(); web.close();
  }
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
