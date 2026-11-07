import 'settings.dart';

/// Levels, XP awards and avatar unlocks. Pure maths over [Settings].
class Progress {
  /// XP needed to go from [level] to the next one: 100, 150, 200, …
  static int stepFor(int level) => 100 + 50 * (level - 1);

  static ({int level, int into, int need}) levelOf(int xp) {
    var level = 1;
    var left = xp;
    while (left >= stepFor(level)) {
      left -= stepFor(level);
      level++;
    }
    return (level: level, into: left, need: stepFor(level));
  }

  /// Avatars and the level that unlocks them. The first ones are free.
  static const avatars = <(String, int)>[
    ('🦊', 1), ('🐼', 1), ('🐯', 1), ('🦁', 1), ('🐸', 1), ('🐙', 1), ('🦉', 1), ('🐧', 1),
    ('🐻', 2), ('🐨', 2), ('🐰', 3), ('🐵', 3), ('🐢', 4), ('🐝', 4), ('🦄', 5), ('🐳', 5),
    ('🦋', 6), ('🐞', 6), ('🐦', 7), ('🐠', 8), ('🐬', 9), ('🦈', 10), ('🐲', 12), ('🌟', 15),
  ];

  static int unlockLevel(String avatar) =>
      avatars.firstWhere((a) => a.$1 == avatar, orElse: () => (avatar, 1)).$2;

  /// Records a finished online game; returns what the end screen shows.
  static Gain onlineGame({required int myPoints, required bool won, required int solves, required int drawnSolves}) {
    final s = Settings.I;
    final before = levelOf(s.xp).level;
    final xp = 25 + myPoints ~/ 15 + (won ? 50 : 0);
    s.addStat('games');
    if (won) s.addStat('wins');
    s.addStat('guessed', solves);
    s.addStat('drawn', drawnSolves);
    s.setBest('best', myPoints);
    s.addXp(xp);
    return Gain(xp, before, levelOf(s.xp).level);
  }

  /// Records a finished offline party game.
  static Gain partyGame({required int wordsGuessed}) {
    final s = Settings.I;
    final before = levelOf(s.xp).level;
    final xp = 30 + 5 * wordsGuessed;
    s.addStat('party');
    s.addXp(xp);
    return Gain(xp, before, levelOf(s.xp).level);
  }
}

class Gain {
  Gain(this.xp, this.levelBefore, this.levelAfter);
  final int xp;
  final int levelBefore;
  final int levelAfter;
  bool get levelledUp => levelAfter > levelBefore;
  List<String> get unlocked => [
        for (final a in Progress.avatars)
          if (a.$2 > levelBefore && a.$2 <= levelAfter) a.$1,
      ];
}
