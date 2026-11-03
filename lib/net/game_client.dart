import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  });

  final String id;
  final String name;
  final String avatar;
  int team;
  int score;
  bool solved;
  bool hostMuted;

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
      );
}

class Stroke {
  Stroke({required this.color, required this.width, required this.points});
  final Color color;
  final double width;
  final List<Offset> points; // normalised 0..1 so any screen size matches

  Map<String, dynamic> toJson() => {
        'c': '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'w': width,
        // 4 decimals is a tenth of a pixel on a 1000 px board; keeps messages small
        'p': points.map((o) => {'x': _r4(o.dx), 'y': _r4(o.dy)}).toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> j) => Stroke(
        color: Color(int.parse((j['c'] as String).substring(1), radix: 16) | 0xFF000000),
        width: (j['w'] as num).toDouble(),
        points: (j['p'] as List)
            .map((e) => Offset((e['x'] as num).toDouble(), (e['y'] as num).toDouble()))
            .toList(),
      );
}

double _r4(double v) => (v * 10000).roundToDouble() / 10000;

/// Accepts `192.168.1.5`, `192.168.1.5:8080`, `ws://192.168.1.5:8080/`
/// and returns `host:port` (port 8080 when none is given).
String normalizeHost(String input) {
  var h = input.trim().replaceFirst(RegExp(r'^wss?://'), '');
  h = h.replaceAll(RegExp(r'/+$'), '');
  if (h.isEmpty) return h;
  final hasPort = RegExp(r':\d+$').hasMatch(h);
  return hasPort ? h : '$h:8080';
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

/// The server could not be reached (wrong address, firewall, not running).
class ConnectFailed implements Exception {
  const ConnectFailed();
}

/* --------------------------- the client --------------------------- */

/// Talks to the Node server. Holds only what the server tells it — in
/// particular it never knows the answer word unless this device is drawing.
class GameClient extends ChangeNotifier {
  WebSocketChannel? _ch;
  StreamSubscription? _sub;

  String? myId;
  String? roomCode;
  bool voiceAllowed = false;
  bool isHost = false;
  String mode = 'ffa';
  Phase phase = Phase.idle;

  List<Player> players = [];
  List<int> teamScore = [0, 0];
  int turn = 0, turns = 0;

  // current turn
  Role role = Role.watcher;
  String? myWord; // non-null only when drawing
  List<String?> mask = [];
  String? drawerId;
  String drawerName = '';
  int drawerTeam = 0;
  int secondsLeft = 0;
  int clockTotal = 0; // length of the current countdown, from the server
  bool micAllowed = true;
  bool stealOpen = false;
  int stealPoints = 75;

  List<String> wordChoices = [];
  final List<Stroke> strokes = [];
  final List<ChatLine> chat = [];

  // results
  String? revealedWord;
  Map<String, int> gains = {};
  bool gameOver = false;
  String? winnerId;
  int? winnerTeam;

  String? error;
  Timer? _tick;

  bool get connected => _ch != null;

  /// This device solved the current word (it is not the drawer).
  bool get iSolved => !iAmDrawer && (me?.solved ?? false);
  Player? get me => players.where((p) => p.id == myId).firstOrNull;
  bool get iAmDrawer => role == Role.drawer;
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
    if (code != null && code.isNotEmpty) q['code'] = code;
    if (public) q['type'] = 'public';
    final uri = Uri.parse('ws://${normalizeHost(host)}/').replace(queryParameters: q);

    final ch = WebSocketChannel.connect(uri);
    try {
      await ch.ready.timeout(const Duration(seconds: 6));
    } catch (_) {
      ch.sink.close();
      throw const ConnectFailed();
    }
    _ch = ch;
    phase = Phase.lobby;
    notifyListeners();

    _sub = _ch!.stream.listen(
      (raw) => _handle(jsonDecode(raw as String) as Map<String, dynamic>),
      onError: (e) {
        error = 'اتصال قطع شد';
        notifyListeners();
      },
      onDone: () {
        error ??= 'ارتباط با سرور قطع شد';
        _ch = null;
        _tick?.cancel();
        notifyListeners();
      },
    );
  }

  void _send(Map<String, dynamic> m) => _ch?.sink.add(jsonEncode(m));

  /* ---- outgoing ---- */
  void setMode(String m) => _send({'t': 'mode', 'mode': m});
  void start() => _send({'t': 'start'});
  void pickWord(int i) => _send({'t': 'pick', 'i': i});
  void skipWord() => _send({'t': 'skip'});
  void doneDrawing() => _send({'t': 'done'});
  void clearCanvas() {
    strokes.clear();
    _send({'t': 'clear'});
    notifyListeners();
  }

  void sendStroke(Stroke s) {
    strokes.add(s);
    _send({'t': 'stroke', 's': s.toJson()});
    notifyListeners();
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
        break;

      case 'room':
        mode = (m['mode'] ?? 'ffa') as String;
        isHost = m['hostId'] == myId;
        players = (m['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList();
        teamScore = List<int>.from((m['teamScore'] ?? [0, 0]) as List);
        turn = (m['turn'] ?? 0) as int;
        turns = (m['turns'] ?? 0) as int;
        phase = _phaseFrom(m['phase'] as String?);
        break;

      case 'choices':
        wordChoices = List<String>.from(m['words'] as List);
        phase = Phase.choosing;
        break;

      case 'waiting':
        wordChoices = [];
        drawerId = m['drawer'] as String?;
        drawerName = (m['drawerName'] ?? '') as String;
        phase = Phase.choosing;
        break;

      case 'turn':
        strokes.clear();
        chat.clear();
        stealOpen = false;
        revealedWord = null;
        role = switch (m['role'] as String) {
          'drawer' => Role.drawer,
          'guesser' => Role.guesser,
          _ => Role.watcher,
        };
        myWord = m['word'] as String?; // present only for the drawer
        mask = m['mask'] == null
            ? []
            : (m['mask'] as List).map((e) => e as String?).toList();
        drawerId = m['drawer'] as String? ?? drawerId;
        drawerName = (m['drawerName'] ?? drawerName) as String;
        drawerTeam = (m['team'] ?? 0) as int;
        _startClock((m['seconds'] as num).toInt());
        phase = Phase.drawing;
        break;

      case 'mic':
        micAllowed = (m['allowed'] ?? true) as bool;
        break;

      case 'hint':
        final i = m['i'] as int;
        if (i < mask.length) mask[i] = m['ch'] as String;
        break;

      case 'stroke':
        strokes.add(Stroke.fromJson(m['s'] as Map<String, dynamic>));
        break;

      case 'clear':
        strokes.clear();
        break;

      case 'chat':
        chat.add(ChatLine(
          (m['name'] ?? '') as String,
          (m['text'] ?? '') as String,
          kind: m['kind'] == 'near' ? ChatKind.near : ChatKind.normal,
          scope: m['scope'] as String?,
        ));
        break;

      case 'solved':
        chat.add(ChatLine((m['name'] ?? '') as String,
            'جوابو زد! +${m['points']}',
            kind: ChatKind.hit));
        for (final p in players) {
          if (p.id == m['from']) p.solved = true;
        }
        break;

      case 'youSolved':
        myWord = m['word'] as String?; // now safe: this device already solved it
        break;

      case 'steal':
        stealOpen = true;
        stealPoints = (m['points'] ?? 75) as int;
        phase = Phase.stealing;
        _startClock((m['seconds'] as num).toInt());
        chat.add(ChatLine('بازی', 'وقت تموم شد — تیم مقابل می‌تونه بدزده',
            kind: ChatKind.system));
        break;

      case 'results':
        _tick?.cancel();
        stealOpen = false;
        revealedWord = m['word'] as String?;
        gains = Map<String, int>.from((m['gains'] ?? {}) as Map);
        players = (m['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList();
        teamScore = List<int>.from((m['teamScore'] ?? [0, 0]) as List);
        gameOver = (m['final'] ?? false) as bool;
        phase = Phase.results;
        break;

      case 'over':
        _tick?.cancel();
        phase = Phase.over;
        gameOver = true;
        players = (m['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList();
        teamScore = List<int>.from((m['teamScore'] ?? [0, 0]) as List);
        if ((m['mode'] as String) == 'team') {
          winnerTeam = m['winner'] as int?;
        } else {
          winnerId = m['winner'] as String?;
        }
        break;

      case 'denied':
        chat.add(ChatLine('بازی', 'الان نوبت تیم تو نیست', kind: ChatKind.system));
        break;

      case 'kicked':
        error = 'میزبان تو رو از اتاق خارج کرد';
        break;

      case 'error':
        error = switch (m['why']) {
          'in_progress' => 'بازی شروع شده — بعداً امتحان کن',
          'need_players' => 'حداقل دو نفر لازمه',
          _ => 'خطا',
        };
        break;
    }
    notifyListeners();
  }

  Phase _phaseFrom(String? s) => switch (s) {
        'lobby' => Phase.lobby,
        'choosing' => Phase.choosing,
        'drawing' => Phase.drawing,
        'stealing' => Phase.stealing,
        'results' => Phase.results,
        'over' => Phase.over,
        _ => phase,
      };

  void _startClock(int seconds) {
    _tick?.cancel();
    secondsLeft = seconds;
    clockTotal = seconds;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        secondsLeft = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    super.dispose();
  }
}

