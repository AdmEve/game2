'use strict';
/* Pure game rules. No networking here, so it can be unit-tested and reused. */

/* ---------- Persian normalisation & matching ---------- */
const norm = s => String(s)
  .replace(/[\u064B-\u0652\u0670\u0653-\u0655]/g, '')  // harakat
  .replace(/\u0640/g, '')                              // tatweel
  .replace(/[\u200b-\u200f\u2066-\u2069]/g, '')        // ZWNJ + bidi
  .replace(/[\u06F0-\u06F9]/g, d => d.charCodeAt(0) - 0x06F0)
  .replace(/[\u0660-\u0669]/g, d => d.charCodeAt(0) - 0x0660)
  .replace(/[يېۍێ]/g, 'ی')
  .replace(/[كڪ]/g, 'ک')
  .replace(/[أإآٱا]/g, 'ا')
  .replace(/ؤ/g, 'و').replace(/ئ/g, 'ی').replace(/ء/g, '')
  .replace(/[ةۀ]/g, 'ه')
  .replace(/\s+/g, '')
  .toLowerCase().trim();

const ALIASES = {
  'دوچرخه': ['بایسیکل'],
  'هلی‌کوپتر': ['هلیکوپتر', 'بالگرد'],
  'کوه دماوند': ['دماوند'],
  'برج آزادی': ['آزادی'],
  'تخت جمشید': ['پرسپولیس'],
  'چهارشنبه‌سوری': ['چارشنبه سوری'],
};

function lev(a, b) {
  const m = [];
  for (let i = 0; i <= b.length; i++) m[i] = [i];
  for (let j = 0; j <= a.length; j++) m[0][j] = j;
  for (let i = 1; i <= b.length; i++)
    for (let j = 1; j <= a.length; j++)
      m[i][j] = b[i - 1] === a[j - 1] ? m[i - 1][j - 1]
        : Math.min(m[i - 1][j - 1], m[i][j - 1], m[i - 1][j]) + 1;
  return m[b.length][a.length];
}

/** 'correct' | 'close' | 'wrong' — the only place the answer is compared. */
function judge(guess, word) {
  const g = norm(guess);
  let best = Infinity;
  for (const c of [word, ...(ALIASES[word] || [])]) best = Math.min(best, lev(g, norm(c)));
  if (best === 0) return 'correct';
  const tol = Math.max(1, Math.floor(norm(word).length / 4));
  return best <= tol ? 'close' : 'wrong';
}

/* ---------- words ---------- */
const WORDS = {
  e: ['سماور', 'هندوانه', 'چتر', 'عینک', 'ماهی', 'کلید', 'قوری', 'گربه', 'دوچرخه', 'ساعت', 'قایق', 'پیتزا'],
  m: ['فرش ایرانی', 'دیزی', 'بادگیر', 'آبشار', 'فانوس دریایی', 'آسیاب بادی', 'هلی‌کوپتر', 'قطار', 'کندو'],
  h: ['تخت جمشید', 'برج آزادی', 'کوه دماوند', 'چهارشنبه‌سوری', 'شب یلدا', 'هفت‌سین', 'زورخانه', 'قنات'],
};
const pick = a => a[Math.floor(Math.random() * a.length)];
/**
 * One easy, one medium, one hard word, none offered before in this game
 * ([used] is updated). A tier that runs out starts over.
 */
function wordChoices(used = new Set()) {
  return ['e', 'm', 'h'].map(tier => {
    let fresh = WORDS[tier].filter(w => !used.has(w));
    if (!fresh.length) {
      WORDS[tier].forEach(w => used.delete(w));
      fresh = WORDS[tier];
    }
    const w = pick(fresh);
    used.add(w);
    return w;
  });
}

/* ---------- scoring ---------- */
const STEAL_POINTS = 75;
const STEAL_SECONDS = 10;
const guessPoints = (secsLeft, turnLen) =>
  Math.round(100 + (Math.max(secsLeft, 0) / turnLen) * 200);
const drawerPoints = (solved, possible) =>
  Math.round(150 * (solved / Math.max(1, possible)));

/** Letter mask sent to guessers: never the word itself. */
const maskOf = w => [...w].map(ch => (ch === ' ' || ch === '\u200c') ? ch : null);

module.exports = {
  norm, lev, judge, ALIASES, WORDS, wordChoices,
  guessPoints, drawerPoints, maskOf, STEAL_POINTS, STEAL_SECONDS,
};
