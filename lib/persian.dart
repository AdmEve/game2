/// Persian text handling. The authoritative [judge] runs on the server —
/// this copy exists only for offline practice mode and instant local feedback.
/// Never trust it for scoring in a networked game.
library;

const _aliases = <String, List<String>>{
  'دوچرخه': ['بایسیکل'],
  'هلی‌کوپتر': ['هلیکوپتر', 'بالگرد'],
  'کوه دماوند': ['دماوند'],
  'برج آزادی': ['آزادی'],
  'تخت جمشید': ['پرسپولیس'],
  'چهارشنبه‌سوری': ['چارشنبه سوری'],
};

/// Folds every way the same Persian word can be typed into one canonical form:
/// harakat, tatweel, ZWNJ, both digit sets, and all letterform variants.
String normalizeFa(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0653-\u0655]'), ''); // harakat
  s = s.replaceAll('\u0640', ''); // tatweel
  s = s.replaceAll(RegExp(r'[\u200B-\u200F\u2066-\u2069]'), ''); // ZWNJ + bidi
  s = s.replaceAllMapped(RegExp(r'[\u06F0-\u06F9]'),
      (m) => (m[0]!.codeUnitAt(0) - 0x06F0).toString()); // Persian digits
  s = s.replaceAllMapped(RegExp(r'[\u0660-\u0669]'),
      (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString()); // Arabic digits
  s = s.replaceAll(RegExp(r'[يېۍێ]'), 'ی');
  s = s.replaceAll(RegExp(r'[كڪ]'), 'ک');
  s = s.replaceAll(RegExp(r'[أإآٱا]'), 'ا');
  s = s.replaceAll('ؤ', 'و').replaceAll('ئ', 'ی').replaceAll('ء', '');
  s = s.replaceAll(RegExp(r'[ةۀ]'), 'ه');
  s = s.replaceAll(RegExp(r'\s+'), '');
  return s.toLowerCase().trim();
}

int levenshtein(String a, String b) {
  final m = List.generate(b.length + 1, (i) => List<int>.filled(a.length + 1, 0));
  for (var i = 0; i <= b.length; i++) m[i][0] = i;
  for (var j = 0; j <= a.length; j++) m[0][j] = j;
  for (var i = 1; i <= b.length; i++) {
    for (var j = 1; j <= a.length; j++) {
      m[i][j] = b[i - 1] == a[j - 1]
          ? m[i - 1][j - 1]
          : 1 +
              [m[i - 1][j - 1], m[i][j - 1], m[i - 1][j]]
                  .reduce((x, y) => x < y ? x : y);
    }
  }
  return m[b.length][a.length];
}

enum Verdict { correct, close, wrong }

/// "close" tolerance scales with word length so a four letter word can't be
/// two edits away and still be called close.
Verdict judge(String guess, String word) {
  final g = normalizeFa(guess);
  var best = 1 << 30;
  for (final c in [word, ...(_aliases[word] ?? const [])]) {
    final d = levenshtein(g, normalizeFa(c));
    if (d < best) best = d;
  }
  if (best == 0) return Verdict.correct;
  final tol = (normalizeFa(word).length ~/ 4).clamp(1, 99);
  return best <= tol ? Verdict.close : Verdict.wrong;
}
