'use strict';
// Helpers for driving the Flutter web build of the app with Playwright.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.json': 'application/json', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf', '.css': 'text/css' };

function serveStatic(dir, port) {
  const srv = http.createServer((req, res) => {
    let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (p.endsWith('/')) p += 'index.html';
    const f = path.join(dir, p);
    if (!f.startsWith(dir) || !fs.existsSync(f)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream' });
    fs.createReadStream(f).pipe(res);
  });
  return new Promise(r => srv.listen(port, () => r(srv)));
}

function startGameServer(root, port, env = {}) {
  const proc = spawn('node', [path.join(root, 'server/server.js')], { env: { ...process.env, PORT: String(port), ...env } });
  proc.stderr.on('data', d => process.stderr.write('[server] ' + d));
  return new Promise((res, rej) => {
    proc.stdout.on('data', d => { if (String(d).includes('naqashi server on')) res(proc); });
    setTimeout(() => rej(new Error('server did not start')), 8000);
  });
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

/** Opens the app in a phone-sized page and turns on Flutter's semantics tree. */
async function openPhone(browser, url, scale) {
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: scale, locale: 'fa-IR', hasTouch: false });
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('[page error]', e.message));
  await page.goto(url);
  await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30000 });
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');
  await page.waitForSelector('flt-semantics', { state: 'attached', timeout: 30000 });
  await sleep(300);
  return page;
}

/** Visible texts from the semantics tree (labels and text content). */
async function texts(page) {
  return page.$$eval('flt-semantics', ns => {
    const out = [];
    for (const n of ns) {
      const l = n.getAttribute('aria-label');
      if (l) out.push(l.trim());
      for (const c of n.childNodes) if (c.nodeType === 3 && c.textContent.trim()) out.push(c.textContent.trim());
      for (const c of n.querySelectorAll(':scope > span')) if (c.textContent.trim()) out.push(c.textContent.trim());
    }
    return [...new Set(out)];
  });
}

async function waitText(page, needle, timeout = 15000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const all = await texts(page);
    const hit = all.find(t => typeof needle === 'string' ? t.includes(needle) : needle.test(t));
    if (hit) return hit;
    await sleep(150);
  }
  throw new Error(`timed out waiting for text ${needle}; on screen: ${JSON.stringify(await texts(page))}`);
}

/** Clicks the semantics node whose label or text contains [label]. */
async function tap(page, label) {
  await waitText(page, label);
  const loc = page.locator('flt-semantics').filter({ hasText: label }).last();
  if (await loc.count()) return loc.click({ force: true });
  return page.locator(`flt-semantics[aria-label*="${label}"]`).last().click({ force: true });
}

/** Focuses the [i]th (or 'last') text field on screen and types into it (replacing its content). */
async function typeInto(page, i, text) {
  const all = page.locator('flt-semantics input, flt-semantics textarea');
  const field = i === 'last' ? all.last() : all.nth(i);
  await field.click({ force: true });
  await sleep(150);
  await page.keyboard.press('Control+A');
  await page.keyboard.press('Backspace');
  await page.keyboard.insertText(text);
  await sleep(150);
}

module.exports = { serveStatic, startGameServer, sleep, openPhone, texts, waitText, tap, typeInto };
