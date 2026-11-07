import 'package:flutter_test/flutter_test.dart';
import 'package:naqashi/party/party_rules.dart';

PartyGame game({int turns = 2, int seconds = 60}) =>
    PartyGame(teams: const ['آبی', 'قرمز'], turnsPerTeam: turns, turnSeconds: seconds, mode: PartyMode.draw);

void main() {
  test('turns alternate between the teams', () {
    final g = game();
    expect(g.totalTurns, 4);
    final order = <int>[];
    while (g.stage != PartyStage.over) {
      order.add(g.team);
      g.offer(['a', 'b', 'c']);
      g.pick(0);
      g.solved(30);
      g.next();
    }
    expect(order, [0, 1, 0, 1]);
  });

  test('a solve scores 100-300 by time left, like online games', () {
    final g = game(seconds: 60);
    g.offer(['سیب', 'کباب', 'سیمرغ']);
    g.pick(2);
    expect(g.word, 'سیمرغ');
    expect(g.solved(60), 300);
    expect(g.scores, [300, 0]);
    g.next();
    g.offer(['a', 'b', 'c']);
    g.pick(0);
    expect(g.solved(0), 100);
    expect(g.scores, [300, 100]);
    expect(g.wordsGuessed, 2);
  });

  test('time up opens a steal for the other team, worth a flat 75', () {
    final g = game();
    g.offer(['a', 'b', 'c']);
    g.pick(1);
    g.openSteal();
    expect(g.stage, PartyStage.steal);
    expect(g.stealResult(true), 75);
    expect(g.scores, [0, 75]);
    expect(g.last!.byTeam, 1);
  });

  test('a failed steal scores nobody', () {
    final g = game();
    g.offer(['a', 'b', 'c']);
    g.pick(0);
    g.openSteal();
    expect(g.stealResult(false), 0);
    expect(g.scores, [0, 0]);
    expect(g.last!.byTeam, isNull);
  });

  test('one reshuffle per turn', () {
    final g = game();
    g.offer(['a', 'b', 'c']);
    expect(g.canReshuffle, isTrue);
    g.reshuffle(['d', 'e', 'f']);
    expect(g.choices, ['d', 'e', 'f']);
    expect(g.canReshuffle, isFalse);
    g.reshuffle(['x', 'y', 'z']);
    expect(g.choices, ['d', 'e', 'f']);
    g.pick(0);
    g.solved(10);
    g.next();
    expect(g.canReshuffle, isTrue, reason: 'resets each turn');
  });

  test('winner and tie', () {
    final g = game(turns: 1);
    g.offer(['a', 'b', 'c']);
    g.pick(0);
    g.solved(30);
    g.next();
    g.offer(['a', 'b', 'c']);
    g.pick(0);
    g.solved(30);
    g.next();
    expect(g.stage, PartyStage.over);
    expect(g.winner, isNull, reason: 'equal scores tie');
    expect(g.round, 2);
  });
}
