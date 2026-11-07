import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// The shared word bank (assets/words/fa.json) for offline party games.
/// Online games never use this: the server picks and holds the word.
class WordBank {
  WordBank._(this.tiers, this.categoryOf);

  /// tier (1 easy, 2 medium, 3 hard) → words
  final Map<int, List<String>> tiers;
  final Map<String, String> categoryOf;

  static WordBank? _cached;

  static Future<WordBank> load() async {
    if (_cached != null) return _cached!;
    final j = jsonDecode(await rootBundle.loadString('assets/words/fa.json')) as Map<String, dynamic>;
    final labels = (j['categories'] as Map).cast<String, String>();
    final tiers = <int, List<String>>{};
    final cat = <String, String>{};
    (j['tiers'] as Map).forEach((tier, cats) {
      final list = tiers.putIfAbsent(int.parse(tier as String), () => []);
      (cats as Map).forEach((c, words) {
        for (final w in (words as List).cast<String>()) {
          list.add(w);
          cat[w] = labels[c] ?? '';
        }
      });
    });
    return _cached = WordBank._(tiers, cat);
  }

  /// One easy, one medium, one hard word, avoiding [avoid] while possible.
  List<String> choices(Set<String> avoid, [Random? rng]) {
    final r = rng ?? Random();
    return [
      for (final t in [1, 2, 3])
        () {
          final fresh = tiers[t]!.where((w) => !avoid.contains(w)).toList();
          final from = fresh.isEmpty ? tiers[t]! : fresh;
          return from[r.nextInt(from.length)];
        }(),
    ];
  }

  int get size => tiers.values.fold(0, (a, b) => a + b.length);
}
