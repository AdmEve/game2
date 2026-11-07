// End-to-end protocol test: the app's real GameClient against the real Node
// server (server/server.js), over real WebSockets. Catches client/server
// disagreements on message names, field names and phase transitions.
//
// Needs Node and `npm install` in server/. Run: flutter test test/protocol_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:naqashi/theme.dart';
import 'package:naqashi/draw/board.dart';
import 'package:naqashi/net/game_client.dart';

const turnSeconds = 4; // server TURN_SECONDS override, so the steal test is quick

late Process server;
late String host;

Future<void> until(GameClient c, bool Function() cond, String what,
    {Duration timeout = const Duration(seconds: 8)}) {
  if (cond()) return Future.value();
  final done = Completer<void>();
  void check() {
    if (!done.isCompleted && cond()) done.complete();
  }

  c.addListener(check);
  return done.future
      .timeout(timeout, onTimeout: () => throw TestFailure('timed out waiting for: $what'))
      .whenComplete(() => c.removeListener(check));
}

Future<void> all(List<GameClient> cs, bool Function(GameClient) cond, String what) =>
    Future.wait(cs.map((c) => until(c, () => cond(c), what)));

Future<GameClient> join(String name, {String? code, bool public = false}) async {
  final c = GameClient();
  await c.connect(host: host, name: name, avatar: '🦊', code: code, public: public);
  await until(c, () => c.myId != null && c.players.isNotEmpty, '$name joined');
  return c;
}

/// Waits until a new turn is offered and returns its drawer.
Future<GameClient> nextDrawer(List<GameClient> cs) async {
  final found = Completer<GameClient>();
  void check() {
    if (found.isCompleted) return;
    final offered = cs.where((c) => c.phase == Phase.choosing && c.wordChoices.isNotEmpty);
    final waiting = cs.where((c) => c.phase == Phase.choosing && c.wordChoices.isEmpty);
    if (offered.length == 1 && waiting.length == cs.length - 1) found.complete(offered.first);
  }

  for (final c in cs) {
    c.addListener(check);
  }
  check();
  try {
    return await found.future.timeout(const Duration(seconds: 8),
        onTimeout: () => throw TestFailure('no drawer was offered words'));
  } finally {
    for (final c in cs) {
      c.removeListener(check);
    }
  }
}

/// A guess at edit distance 1 from [word]: the server calls this "close".
String nearMiss(String word) => word.substring(0, word.length - 1);

void main() {
  setUpAll(() async {
    if (!Directory('server/node_modules/ws').existsSync()) {
      fail('run `npm install` in server/ first');
    }
    final port = 20000 + Random().nextInt(20000);
    server = await Process.start('node', ['server/server.js'], environment: {
      'PORT': '$port',
      'TURN_SECONDS': '$turnSeconds',
      'RESULT_PAUSE_MS': '300',
    });
    server.stderr.transform(utf8.decoder).listen((e) => stderr.write('[server] $e'));
    await server.stdout
        .transform(utf8.decoder)
        .firstWhere((l) => l.contains('naqashi server on'))
        .timeout(const Duration(seconds: 10));
    host = '127.0.0.1:$port';
  });

  tearDownAll(() => server.kill());

  test('free-for-all: a whole game from lobby to the final scoreboard', () async {
    final a = await join('میزبان');
    expect(a.roomCode, isNotNull, reason: 'a private room has a code');
    expect(a.voiceAllowed, isTrue, reason: 'private rooms allow voice');
    final b = await join('سارا', code: a.roomCode);
    final c = await join('میلاد', code: a.roomCode);
    final everyone = [a, b, c];
    await all(everyone, (x) => x.players.length == 3, 'three players in the lobby');
    expect(a.isHost, isTrue);
    expect(b.isHost || c.isHost, isFalse);
    expect(everyone.every((x) => x.phase == Phase.lobby), isTrue);

    b.start(); // not the host: ignored
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(a.phase, Phase.lobby, reason: 'only the host can start');

    a.start();

    // ---- turn 1, checked in detail ----
    final d = await nextDrawer(everyone);
    final guessers = everyone.where((x) => x != d).toList();
    expect(d.wordChoices, hasLength(3));
    for (final g in guessers) {
      expect(g.drawerName, d.me!.name);
    }

    d.pickWord(0);
    await all(everyone, (x) => x.phase == Phase.drawing, 'drawing phase');
    final word = d.myWord!;
    expect(d.role, Role.drawer);
    for (final g in guessers) {
      expect(g.role, Role.guesser);
      expect(g.myWord, isNull, reason: 'guessers never receive the word');
      expect(g.mask, hasLength(word.length), reason: 'mask has one slot per letter');
      expect(g.canGuess, isTrue);
    }
    expect(d.secondsLeft, turnSeconds);

    // a stroke reaches the guessers with colour, width and points intact
    d.sendStroke(Stroke(id: 0, color: const Color(0xFFE14D63), width: 6, points: [const Offset(.1, .2), const Offset(.5, .5)]));
    await all(guessers, (x) => x.board.strokes.length == 1, 'stroke arrives');
    final s = guessers.first.board.strokes.single;
    expect(s.color, const Color(0xFFE14D63));
    expect(s.width, 6);
    expect(s.points.last, const Offset(.5, .5));

    // live: points stream while the finger is still down
    final live = Stroke(id: d.board.nextId, color: C.ink, width: 7, points: [const Offset(.2, .2)]);
    d.board.begin(live);
    d.strokePoints(live, [const Offset(.2, .2)], true);
    await all(guessers, (x) => x.board.strokes.length == 2, 'a new stroke appears before the finger lifts');
    d.board.extend(live.id, [const Offset(.3, .3), const Offset(.4, .35)]);
    d.strokePoints(live, [const Offset(.3, .3), const Offset(.4, .35)], false);
    await all(guessers, (x) => x.board.strokes.last.points.length == 3, 'more points of the same stroke follow');
    d.strokeEnd(live);

    d.undo();
    await all(guessers, (x) => x.board.strokes.length == 1, 'undo removes the last stroke everywhere');

    d.clearCanvas();
    await all(guessers, (x) => x.board.isEmpty, 'clear arrives');

    final g1 = guessers[0], g2 = guessers[1];

    // a wrong guess is public
    g1.guess('زرافه‌ی بنفش');
    await all(everyone, (x) => x.chat.any((l) => l.text == 'زرافه‌ی بنفش'), 'wrong guess is public');

    // a near miss is shown only to the guesser
    if (word.length >= 2) {
      final near = nearMiss(word);
      g2.guess(near);
      await until(g2, () => g2.chat.any((l) => l.kind == ChatKind.near), 'near miss shown to guesser');
      expect(g2.chat.last.scope, 'private');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(g1.chat.any((l) => l.text == near), isFalse, reason: 'near miss is private');
      expect(d.chat.any((l) => l.text == near), isFalse, reason: 'near miss is private');
    }

    // a correct guess: solver learns the word, everyone learns who solved
    g1.guess(word);
    await until(g1, () => g1.myWord == word, 'solver receives the word');
    await all(everyone, (x) => x.chat.any((l) => l.kind == ChatKind.hit), 'solved is announced');
    expect(g2.myWord, isNull, reason: 'the solved broadcast does not carry the word');
    expect(g2.chat.any((l) => l.text.contains(word)), isFalse);
    expect(g2.players.firstWhere((p) => p.id == g1.myId).solved, isTrue);

    // after solving, chat reaches solvers and the drawer only
    g1.guess('آفرین به نقاش');
    await until(d, () => d.chat.any((l) => l.text == 'آفرین به نقاش'), 'drawer sees solver chat');
    expect(d.chat.last.scope, 'solvers');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(g2.chat.any((l) => l.text == 'آفرین به نقاش'), isFalse,
        reason: 'unsolved players do not see solver chat');

    // last guesser solves: the turn ends early with the word revealed
    g2.guess(word);
    await all(everyone, (x) => x.phase == Phase.results, 'results');
    for (final x in everyone) {
      expect(x.revealedWord, word);
      expect(x.gains[g1.myId], greaterThan(0));
      expect(x.gains[d.myId], 150, reason: 'drawer gets 150 when everyone solves');
    }
    expect(a.turn, 1);
    expect(a.turns, 6, reason: '3 players x 2 rounds');

    // ---- turns 2..6: everyone solves straight away ----
    for (var t = 2; t <= 6; t++) {
      final dd = await nextDrawer(everyone);
      dd.pickWord(1);
      await all(everyone, (x) => x.phase == Phase.drawing && x.turn == t, 'turn $t drawing');
      // the previous turn's strokes and chat are gone
      expect(everyone.every((x) => x.board.isEmpty), isTrue);
      for (final g in everyone.where((x) => x != dd)) {
        expect(g.myWord, isNull, reason: 'turn $t: a guesser does not hold last turn\'s word');
        g.guess(dd.myWord!);
      }
      await all(everyone, (x) => x.phase == Phase.results || x.phase == Phase.over, 'turn $t results');
    }

    await all(everyone, (x) => x.phase == Phase.over, 'game over');
    final best = [...a.players]..sort((p, q) => q.score.compareTo(p.score));
    for (final x in everyone) {
      expect(x.gameOver, isTrue);
      expect(x.winnerId, best.first.id);
    }

    for (final x in everyone) {
      x.dispose();
    }
  });

  test('team mode: gating, steal window, first solve ends the turn', () async {
    final a = await join('آرش');
    final b = await join('بهار', code: a.roomCode);
    final c = await join('کاوه', code: a.roomCode);
    final d = await join('دریا', code: a.roomCode);
    final everyone = [a, b, c, d];
    await all(everyone, (x) => x.players.length == 4, 'four players');

    a.setMode('team');
    await all(everyone, (x) => x.mode == 'team', 'mode is team');
    // join order alternates teams: a,c = 0 (blue), b,d = 1 (red)
    expect(a.me!.team, 0);
    expect(b.me!.team, 1);
    expect(c.me!.team, 0);
    expect(d.me!.team, 1);

    a.start();

    // ---- turn 1: team 0 draws, nobody solves, team 1 steals ----
    final d1 = await nextDrawer(everyone);
    expect(d1, a, reason: 'turn order follows join order');
    a.pickWord(0);
    await all(everyone, (x) => x.phase == Phase.drawing, 'drawing');
    final word = a.myWord!;
    expect(c.role, Role.guesser, reason: "drawer's teammate guesses");
    expect(b.role, Role.watcher, reason: 'other team watches');
    expect(d.role, Role.watcher);
    expect(b.canGuess, isFalse);

    // a watcher's guess is refused, even a correct one
    b.guess(word);
    await until(b, () => b.chat.any((l) => l.kind == ChatKind.system), 'watcher is told no');
    expect(b.myWord, isNull);

    // nobody guesses; the clock runs out and the other team may steal
    await all(everyone, (x) => x.phase == Phase.stealing, 'steal window',);
    expect(b.canGuess, isTrue, reason: 'stealing team may guess');
    expect(d.canGuess, isTrue);
    expect(c.canGuess, isFalse, reason: "drawing team may not guess during the other team's steal");
    expect(a.canGuess, isFalse);

    d.guess(word);
    await all(everyone, (x) => x.phase == Phase.results, 'results after steal');
    for (final x in everyone) {
      expect(x.teamScore, [0, 75], reason: 'steal is a flat 75 to the stealing team');
      expect(x.revealedWord, word);
    }

    // ---- turn 2: team 1 draws, first correct guess ends the turn ----
    final d2 = await nextDrawer(everyone);
    expect(d2, b);
    b.pickWord(0);
    await all(everyone, (x) => x.phase == Phase.drawing && x.turn == 2, 'turn 2 drawing');
    expect(d.role, Role.guesser);
    expect(a.role, Role.watcher);
    expect(c.role, Role.watcher);
    d.guess(b.myWord!);
    await all(everyone, (x) => x.phase == Phase.results, 'turn 2 results');
    expect(a.teamScore[1], greaterThan(75));
    expect(a.teamScore[0], 0);

    for (final x in everyone) {
      x.dispose();
    }
  });

  test('public rooms: no code shown, no voice', () async {
    final a = await join('عمومی۱', public: true);
    final b = await join('عمومی۲', public: true);
    await all([a, b], (x) => x.players.length == 2, 'matched into one public room');
    expect(a.roomCode, isNull);
    expect(a.voiceAllowed, isFalse);
    a.dispose();
    b.dispose();
  });

  test('host settings, play again', () async {
    final a = await join('میزبان');
    final b = await join('مهمان', code: a.roomCode);
    await all([a, b], (x) => x.players.length == 2, 'two players');
    a.setRounds(1);
    a.setTurnLen(45);
    await all([a, b], (x) => x.rounds == 1 && x.turnLen == 45 && !x.turnLenAuto, 'settings reach everyone');
    a.start();
    for (var t = 1; t <= 2; t++) {
      final d = await nextDrawer([a, b]);
      d.pickWord(0);
      await all([a, b], (x) => x.phase == Phase.drawing && x.turn == t, 'turn $t');
      expect(d.clockTotal, 45);
      (d == a ? b : a).guess(d.myWord!);
      await all([a, b], (x) => x.phase == Phase.results || x.phase == Phase.over, 'turn $t done');
    }
    await all([a, b], (x) => x.phase == Phase.over, 'one-round game over');
    a.playAgain();
    await all([a, b], (x) => x.phase == Phase.lobby && !x.gameOver && x.players.every((p) => p.score == 0), 'back to the lobby');
    a.dispose();
    b.dispose();
  });

  test('a dropped connection resumes with the full state', () async {
    final a = await join('نقاش');
    final b = await join('حدس‌زن', code: a.roomCode);
    await all([a, b], (x) => x.players.length == 2, 'two players');
    a.start();
    final d = await nextDrawer([a, b]);
    final g = d == a ? b : a;
    d.pickWord(0);
    await all([a, b], (x) => x.phase == Phase.drawing, 'drawing');
    d.sendStroke(Stroke(id: 0, color: C.ink, width: 6, points: [const Offset(.1, .1), const Offset(.9, .9)]));
    await until(g, () => g.board.strokes.length == 1, 'stroke arrives');

    g.debugDropConnection();
    await until(g, () => g.reconnecting, 'notices the drop');
    await until(d, () => d.players.any((p) => p.id == g.myId && p.away), 'others see them away');
    await until(g, () => !g.reconnecting && g.connected, 'resumes', timeout: const Duration(seconds: 10));
    expect(g.phase, Phase.drawing);
    expect(g.role, Role.guesser);
    expect(g.myWord, isNull, reason: 'a resumed guesser still has no word');
    expect(g.board.strokes.length, 1, reason: 'the drawing comes back');
    expect(g.secondsLeft, greaterThan(0));
    g.guess(d.myWord!);
    await until(g, () => g.myWord != null, 'can still score after resuming');
    a.dispose();
    b.dispose();
  });

  test('a mistyped room code is refused', () async {
    final c = GameClient();
    await expectLater(c.connect(host: host, name: 'گم', avatar: '🦊', code: 'ZZZZZ'),
        throwsA(isA<ConnectFailed>().having((e) => e.why, 'why', 'no_room')));
    c.dispose();
  });

  test('a kicked player is told and disconnected', () async {
    final a = await join('میزبان');
    final b = await join('مزاحم', code: a.roomCode);
    await all([a, b], (x) => x.players.length == 2, 'two players');
    a.hostKick(b.myId!);
    await until(b, () => b.error != null && !b.connected, 'kicked player disconnected');
    await until(a, () => a.players.length == 1, 'host sees them gone');
    a.dispose();
  });
}
