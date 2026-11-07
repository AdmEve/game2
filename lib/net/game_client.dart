import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../draw/board.dart';
import '../theme.dart' show fa;

/* ----------------------------- models ----------------------------- */

class Player {
  Player({
    required this.id,
    required this.name,
    required this.avatar,
    this.team = 0,
    this.score = 0,
    this.solved = false,
    this.hostMuted = false,
    this.away = false,
  });

  final String id;
  final String name;
  final String avatar;
  int team;
  int score;
  bool solved;
  bool hostMuted;
  bool away;

  /// Local-only: this device muted them for itself.
  bool localMuted = false;

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        avatar: (j['avatar'] ?? '🦊') as String,
        team: (j['team'] ?? 0) as int,
        score: (j['score'] ?? 0) as int,
        solved: (j['solved'] ?? false) as bool,
        hostMuted: (j['hostMuted'] ?? false) as bool,
        away: (j['away'] ?? false) as bool,
      );
}

class ChatLine {
  ChatLine(this.name, this.text, {this.kind = ChatKind.normal, this.scope});
  final String name;
  final String text;
  final ChatKind kind;
  final String? scope; // 'private' | 'solvers'
}

enum ChatKind { normal, near, hit, system }

enum Phase { idle, lobby, choosing, drawing, stealing, results, over }

enum Role { drawer, guesser, watcher }

/// One-off moments the UI reacts to with sound, haptics and animation.
enum Ev { turnStart, youSolved, otherSolved, near, hint, steal, tick, timeUp, results, over, joined, left, reconnecting, reconnected }

class GameEvent {
  GameEvent(this.kind, {this.name = '', this.points = 0, this.seconds = 0});
  final Ev kind;
  final String name;
  final int points;
  final int seconds;
}

/// Accepts `192.168.1.5`, `192.168.1.5:8080`, `ws://192.168.1.5:8080/`
/// and returns `host:port` (port 8080 when none is given).
String normalizeHost(String input) {
  var h = input.trim().replaceFirst(RegExp(r'^wss?://'), '');
  h = h.replaceAll(RegExp(r'/+$'), '');
  if (h.isEmpty) return h;
  final hasPort = RegExp(r':\d+$').hasMatch(h);
  return hasPort ? h : '$h:8080';
}

/// The server could not be reached, or refused (e.g. unknown room code).
class ConnectFailed implements Exception {
  const ConnectFailed([this.why = 'unreachable']);
  final String why;
}

/* --------------------------- the client --------------------------- */

/// Talks to the Node server. Holds only what the server tells it — in
/// particular it never knows the answer word unless this device is drawing
/// or has already solved it.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  String _host = '';
  String? _token;
  bool _leaving = false;
  Timer? _retry;
  DateTime? _dropAt;

  final _events = StreamController<GameEvent>.broadcast();
  Stream<GameEvent> get events => _events.stream;

  String? myId;
  String? roomCode;
  bool voiceAllowed = false;
  bool isHost = false;
  String? hostId;
  String mode = 'ffa';
  Phase phase = Phase.idle;
  bool reconnecting = false;

  List<Player> players = [];
  List<int> teamScore = [0, 0];
  int turn = 0, turns = 0;
  int rounds = 2;
  int turnLen = 80;
  bool turnLenAuto = true;

  // current turn
  Role role = Role.watcher;
  String? myWord; // the drawer's word, or the word after this device solved it
  List<String?> mask = [];
  String? drawerId;
  String drawerName = '';
  int drawerTeam = 0;
  int secondsLeft = 0;
  int clockTotal = 0;
  bool micAllowed = true;
  bool stealOpen = false;
  int stealPoints = 75;

  List<String> wordChoices = [];
  final BoardModel board = BoardModel();
  late final StrokeSender _sender = StrokeSender(_send);
  final List<ChatLine> chat = [];

  // results
  String? revealedWord;
  String? lastDrawerId;
  Map<String, int> gains = {};
  bool gameOver = false;
  String? winnerId;
  int? winnerTeam;
  String? mvpId;

  // this device's game, for the end screen and progression
  int mySolves = 0;
  int myDrawingsSolved = 0;

  String? error;
  Timer? _tick;

  bool get connected => _ch != null;
  Player? get me => players.where((p) => p.id == myId).firstOrNull;
  Player? get drawer => players.where((p) => p.id == drawerId).firstOrNull;
  bool get iAmDrawer => role == Role.drawer;

  /// This device solved the current word (it is not the drawer).
  bool get iSolved => !iAmDrawer && (me?.solved ?? false);

  /// Show voice controls: the room allows voice and voice actually exists.
  bool get voiceOn => kVoiceBuilt && voiceAllowed;

  /// Mirrors the server's mayGuess(): during a steal only the other team may
  /// guess; otherwise only players the server made guessers this turn.
  bool get canGuess => phase == Phase.stealing
      ? stealOpen && _onStealingTeam
      : phase == Phase.drawing && role == Role.guesser;
  bool get _onStealingTeam => me != null && me!.team != drawerTeam;

  Future<void> connect({
    required String host,
    required String name,
    required String avatar,
    String? code,
    bool public = false,
  }) async {
    final q = <String, String>{'name': name, 'avatar': avatar};
    if (code != null && code.isNotEmpty) q['code'] = code.toUpperCase();
    if (public) q['type'] = 'public';
    _host = normalizeHost(host);
    if (_host.isEmpty) throw const ConnectFailed();
    final ch = await _open(q);
    // One subscription for the life of the socket. The first message tells us
    // whether we were let in ('you') or refused ('error' and a close).
    final first = Completer<Map<String, dynamic>>();
    _ch = ch;
    phase = Phase.lobby;
    _sub?.cancel();
    _sub = ch.stream.listen(
      (raw) {
        final m = jsonDecode(raw as String) as Map<String, dynamic>;
        if (!first.isCompleted) {
          first.complete(m);
          if (m['t'] == 'error') return;
        }
        _handle(m);
      },
      onError: (_) => first.isCompleted ? _dropped(ch) : first.completeError(const ConnectFailed()),
      onDone: () => first.isCompleted ? _dropped(ch) : first.completeError(const ConnectFailed()),
    );
    Map<String, dynamic> hello;
    try {
      hello = await first.future.timeout(const Duration(seconds: 6));
    } catch (_) {
      _abandon(ch);
      throw const ConnectFailed();
    }
    if (hello['t'] == 'error') {
      _abandon(ch);
      throw ConnectFailed(hello['why'] as String? ?? 'error');
    }
    notifyListeners();
  }

  void _abandon(WebSocketChannel ch) {
    _ch = null;
    phase = Phase.idle;
    _sub?.cancel();
    _sub = null;
    ch.sink.close();
  }

  Future<WebSocketChannel> _open(Map<String, String> q) async {
    final uri = Uri.parse('ws://$_host/').replace(queryParameters: q);
    final ch = WebSocketChannel.connect(uri);
    try {
      await ch.ready.timeout(const Duration(seconds: 6));
    } catch (_) {
      ch.sink.close();
      throw const ConnectFailed();
    }
    return ch;
  }

  void _listen(WebSocketChannel ch) {
    _sub?.cancel();
    _sub = ch.stream.listen(
      (raw) => _handle(jsonDecode(raw as String) as Map<String, dynamic>),
      onError: (_) => _dropped(ch),
      onDone: () => _dropped(ch),
    );
  }

  /// The socket closed. Unless we meant it, try to get our seat back.
  void _dropped(WebSocketChannel ch) {
    if (!identical(ch, _ch)) return;
    _ch = null;
    _sender.reset();
    if (_leaving || error != null || _token == null) {
      _tick?.cancel();
      error ??= 'ارتباط با سرور قطع شد';
      notifyListeners();
      return;
    }
    reconnecting = true;
    _dropAt = DateTime.now();
    _events.add(GameEvent(Ev.reconnecting));
    notifyListeners();
    _scheduleResume();
  }

  void _scheduleResume() {
    _retry?.cancel();
    _retry = Timer(const Duration(milliseconds: 1500), _tryResume);
  }

  Future<void> _tryResume() async {
    if (_leaving || !reconnecting) return;
    if (DateTime.now().difference(_dropAt!) > const Duration(seconds: 25)) {
      reconnecting = false;
      _tick?.cancel();
      error = 'ارتباط با سرور قطع شد و برنگشت';
      notifyListeners();
      return;
    }
    try {
      final ch = await _open({'resume': _token!});
      _ch = ch;
      _listen(ch);
    } catch (_) {
      _scheduleResume();
    }
  }

  void _send(Map<String, dynamic> m) => _ch?.sink.add(jsonEncode(m));

  /// Tests: drop the socket as if the wifi blinked (not a deliberate leave).
  @visibleForTesting
  void debugDropConnection() => _ch?.sink.close();

  /* ---- outgoing ---- */
  void setMode(String m) => _send({'t': 'mode', 'mode': m});
  void setRounds(int r) => _send({'t': 'settings', 'rounds': r});
  void setTurnLen(int? s) => _send({'t': 'settings', 'turnLen': s ?? 'auto'});
  void start() => _send({'t': 'start'});
  void playAgain() => _send({'t': 'again'});
  void pickWord(int i) => _send({'t': 'pick', 'i': i});
  void skipWord() => _send({'t': 'skip'});
  void doneDrawing() {
    _sender.flush();
    _send({'t': 'done'});
  }

  /// Leave on purpose: no grace period, others see us gone at once.
  void leave() {
    _leaving = true;
    _retry?.cancel();
    _send({'t': 'leave'});
    _ch?.sink.close();
  }

  void clearCanvas() {
    _sender.reset();
    board.clear();
    _send({'t': 'clear'});
  }

  void undo() {
    _sender.flush();
    if (board.removeLast() != null) _send({'t': 'undo'});
  }

  /// Called by the drawing surface while the drawer's finger moves.
  void strokePoints(Stroke s, List<Offset> pts, bool isNew) => _sender.add(s, pts, isNew);
  void strokeEnd(Stroke s) => _sender.end(s);

  /// Draws a whole stroke at once (tests, or a tap).
  void sendStroke(Stroke s) {
    board.begin(Stroke(id: board.nextId, color: s.color, width: s.width, points: [...s.points]));
    final mine = board.strokes.last;
    _sender.add(mine, mine.points, true);
    _sender.end(mine);
  }

  void guess(String text) => _send({'t': 'guess', 'text': text});
  void hostMute(String id) => _send({'t': 'mute', 'id': id});
  void hostKick(String id) => _send({'t': 'kick', 'id': id});

  /* ---- incoming ---- */
  void _handle(Map<String, dynamic> m) {
    switch (m['t'] as String) {
      case 'you':
        myId = m['id'] as String?;
        roomCode = m['code'] as String?;
        voiceAllowed = (m['voice'] ?? false) as bool;
        _token = m['token'] as String? ?? _token;

      case 'room':
        _room(m);

      case 'sync':
        _sync(m);

      case 'choices':
        wordChoices = List<String>.from(m['words'] as List);
        phase = Phase.choosing;

      case 'waiting':
        wordChoices = [];
        drawerId = m['drawer'] as String?;
        drawerName = (m['drawerName'] ?? '') as String;
        phase = Phase.choosing;

      case 'turn':
        _sender.reset();
        board.clear();
        chat.clear();
        stealOpen = false;
        revealedWord = null;
        role = switch (m['role'] as String) {
          'drawer' => Role.drawer,
          'guesser' => Role.guesser,
          _ => Role.watcher,
        };
        myWord = m['word'] as String?; // present only for the drawer
        mask = m['mask'] == null ? [] : (m['mask'] as List).map((e) => e as String?).toList();
        drawerId = m['drawer'] as String? ?? drawerId;
        drawerName = (m['drawerName'] ?? drawerName) as String;
        drawerTeam = (m['team'] ?? 0) as int;
        _startClock((m['seconds'] as num).toInt());
        phase = Phase.drawing;
        _events.add(GameEvent(Ev.turnStart, name: drawerName));

      case 'mic':
        micAllowed = (m['allowed'] ?? true) as bool;

      case 'hint':
        final i = m['i'] as int;
        if (i < mask.length) mask[i] = m['ch'] as String;
        _events.add(GameEvent(Ev.hint));

      case 'pts':
        final p = (m['p'] as List).cast<num>();
        final pts = <Offset>[for (var i = 0; i + 1 < p.length; i += 2) Offset(p[i] / 10000, p[i + 1] / 10000)];
        board.extend(m['id'] as int, pts,
            color: m['c'] == null ? null : _color(m['c'] as String), width: (m['w'] as num?)?.toDouble());

      case 'undo':
        board.remove(m['id'] as int);

      case 'clear':
        board.clear();

      case 'chat':
        final line = ChatLine(
          (m['name'] ?? '') as String,
          (m['text'] ?? '') as String,
          kind: m['kind'] == 'near' ? ChatKind.near : ChatKind.normal,
          scope: m['scope'] as String?,
        );
        chat.add(line);
        if (line.kind == ChatKind.near) _events.add(GameEvent(Ev.near));

      case 'solved':
        final pts = (m['points'] ?? 0) as int;
        chat.add(ChatLine((m['name'] ?? '') as String, 'جوابو زد! ${fa(pts)} امتیاز', kind: ChatKind.hit));
        for (final p in players) {
          if (p.id == m['from']) p.solved = true;
        }
        if (m['from'] != myId) _events.add(GameEvent(Ev.otherSolved, name: (m['name'] ?? '') as String, points: pts));
        if (iAmDrawer) myDrawingsSolved++;

      case 'youSolved':
        myWord = m['word'] as String?; // now safe: this device already solved it
        mySolves++;
        _events.add(GameEvent(Ev.youSolved, points: (m['points'] ?? 0) as int));

      case 'steal':
        stealOpen = true;
        stealPoints = (m['points'] ?? 75) as int;
        phase = Phase.stealing;
        _startClock((m['seconds'] as num).toInt());
        chat.add(ChatLine('بازی', 'وقت تموم شد — تیم مقابل می‌تونه بدزده', kind: ChatKind.system));
        _events.add(GameEvent(Ev.steal));

      case 'results':
        _results(m);
        _events.add(GameEvent(Ev.results));

      case 'over':
        _over(m);
        _events.add(GameEvent(Ev.over));

      case 'denied':
        chat.add(ChatLine('بازی',
            m['why'] == 'slow_down' ? 'یواش‌تر! چند ثانیه صبر کن' : 'الان نوبت تیم تو نیست',
            kind: ChatKind.system));

      case 'kicked':
        error = 'میزبان تو رو از اتاق خارج کرد';

      case 'error':
        error = switch (m['why']) {
          'in_progress' => 'بازی شروع شده — بعداً امتحان کن',
          'need_players' => 'حداقل دو نفر لازمه',
          'no_room' => 'اتاقی با این کد پیدا نشد',
          'expired' => 'ارتباط با سرور قطع شد و جات نگه داشته نشد',
          _ => 'خطا',
        };
        if (m['why'] == 'expired') reconnecting = false;
    }
    notifyListeners();
  }

  void _room(Map<String, dynamic> m) {
    final before = players.map((p) => p.id).toSet();
    mode = (m['mode'] ?? 'ffa') as String;
    hostId = m['hostId'] as String?;
    isHost = hostId == myId;
    players = (m['players'] as List).map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
    teamScore = List<int>.from((m['teamScore'] ?? [0, 0]) as List);
    turn = (m['turn'] ?? 0) as int;
    turns = (m['turns'] ?? 0) as int;
    rounds = (m['rounds'] ?? rounds) as int;
    turnLen = (m['turnLen'] ?? turnLen) as int;
    turnLenAuto = (m['turnLenAuto'] ?? turnLenAuto) as bool;
    final newPhase = _phaseFrom(m['phase'] as String?);
    if (newPhase == Phase.lobby && (phase == Phase.over || phase == Phase.results)) _resetForLobby();
    phase = newPhase;
    if (before.isNotEmpty && phase == Phase.lobby) {
      for (final p in players) {
        if (!before.contains(p.id)) _events.add(GameEvent(Ev.joined, name: p.name));
      }
    }
  }

  void _resetForLobby() {
    gameOver = false;
    winnerId = null;
    winnerTeam = null;
    mvpId = null;
    revealedWord = null;
    gains = {};
    board.clear();
    chat.clear();
    mySolves = 0;
    myDrawingsSolved = 0;
  }

  void _results(Map<String, dynamic> m) {
    _tick?.cancel();
    stealOpen = false;
    revealedWord = m['word'] as String?;
    lastDrawerId = m['drawer'] as String?;
    gains = Map<String, int>.from((m['gains'] ?? {}) as Map);
    players = (m['players'] as List).map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
    teamScore = List<int>.from((m['teamScore'] ?? [0, 0]) as List);
    gameOver = (m['final'] ?? false) as bool;
    phase = Phase.results;
  }

  void _over(Map<String, dynamic> m) {
    _tick?.cancel();
    phase = Phase.over;
    gameOver = true;
    players = (m['players'] as List).map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
    teamScore = List<int>.from((m['teamScore'] ?? [0, 0]) as List);
    mvpId = m['mvp'] as String?;
    if ((m['mode'] as String) == 'team') {
      winnerTeam = m['winner'] as int?;
    } else {
      winnerId = m['winner'] as String?;
    }
  }

  /// Rebuilds everything after a resume.
  void _sync(Map<String, dynamic> m) {
    _room(m);
    if (reconnecting) {
      reconnecting = false;
      _events.add(GameEvent(Ev.reconnected));
    }
    drawerId = m['drawer'] as String? ?? drawerId;
    drawerName = (m['drawerName'] ?? drawerName) as String;
    drawerTeam = (m['team'] ?? drawerTeam) as int;
    if (m['role'] != null) {
      role = switch (m['role'] as String) {
        'drawer' => Role.drawer,
        'guesser' => Role.guesser,
        _ => Role.watcher,
      };
    }
    wordChoices = m['choices'] == null ? [] : List<String>.from(m['choices'] as List);
    myWord = m['word'] as String?;
    if (m['mask'] != null) mask = (m['mask'] as List).map((e) => e as String?).toList();
    if (m['strokes'] != null) {
      board.replaceAll([
        for (final s in (m['strokes'] as List).cast<Map<String, dynamic>>())
          Stroke(
            id: s['id'] as int,
            color: _color(s['c'] as String),
            width: (s['w'] as num).toDouble(),
            points: [
              for (var i = 0; i + 1 < (s['p'] as List).length; i += 2)
                Offset(((s['p'] as List)[i] as num) / 10000, ((s['p'] as List)[i + 1] as num) / 10000),
            ],
          ),
      ]);
    }
    if (m['steal'] != null) {
      stealOpen = true;
      stealPoints = ((m['steal'] as Map)['points'] ?? 75) as int;
    }
    if (m['seconds'] != null) {
      _startClock((m['seconds'] as num).toInt(), total: (m['total'] as num?)?.toInt());
    }
    if (m['results'] != null) _results((m['results'] as Map).cast<String, dynamic>());
    if (m['over'] != null) _over((m['over'] as Map).cast<String, dynamic>());
  }

  static Color _color(String hex) => Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

  Phase _phaseFrom(String? s) => switch (s) {
        'lobby' => Phase.lobby,
        'choosing' => Phase.choosing,
        'drawing' => Phase.drawing,
        'stealing' => Phase.stealing,
        'results' => Phase.results,
        'over' => Phase.over,
        _ => phase,
      };

  void _startClock(int seconds, {int? total}) {
    _tick?.cancel();
    secondsLeft = seconds;
    clockTotal = total ?? seconds;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      secondsLeft--;
      if (secondsLeft <= 10 && secondsLeft > 0) _events.add(GameEvent(Ev.tick, seconds: secondsLeft));
      if (secondsLeft <= 0) {
        secondsLeft = 0;
        t.cancel();
        _events.add(GameEvent(Ev.timeUp));
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _retry?.cancel();
    _sender.dispose();
    _sub?.cancel();
    _ch?.sink.close();
    _events.close();
    board.dispose();
    super.dispose();
  }
}
