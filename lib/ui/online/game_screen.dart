import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/progress.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../draw/board.dart';
import '../../net/game_client.dart';
import '../../theme.dart';
import '../fx.dart';
import '../share.dart';
import '../widgets.dart';
import 'lobby.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key, required this.client});
  final GameClient client;

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  Color _color = C.ink;
  double _width = kBrushSizes[1];
  bool _eraser = false;
  StreamSubscription<GameEvent>? _sub;
  bool _lostShown = false;
  String? _shownError;

  int _confetti = 0;
  int _popTrigger = 0;
  int _popPoints = 0;
  Gain? _gain;

  GameClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    _sub = c.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    c.removeListener(_onChange);
    c.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (!c.connected && !c.reconnecting && c.phase != Phase.over && !_lostShown && c.error != null) {
      _lostShown = true;
      _connectionLost(c.error!);
    } else if (c.error != null && c.error != _shownError && c.connected) {
      _shownError = c.error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.error!), backgroundColor: C.anar));
    }
    setState(() {});
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    switch (e.kind) {
      case Ev.turnStart:
        Sfx.play(Snd.turn);
        Sfx.medium();
        _eraser = false;
      case Ev.youSolved:
        Sfx.play(Snd.correct);
        Sfx.heavy();
        setState(() {
          _confetti++;
          _popPoints = e.points;
          _popTrigger++;
        });
      case Ev.otherSolved:
        Sfx.play(Snd.solvedOther);
        Sfx.light();
        showToast(context, '${e.name} حدس زد! +${fa(e.points)}', icon: '🎯');
      case Ev.near:
        Sfx.play(Snd.near);
        Sfx.light();
      case Ev.hint:
        Sfx.play(Snd.hint);
      case Ev.steal:
        Sfx.play(Snd.steal);
        Sfx.heavy();
      case Ev.tick:
        if (e.seconds <= 5) {
          Sfx.play(Snd.tick);
          if (e.seconds <= 3) Sfx.tick();
        }
      case Ev.timeUp:
        if (c.phase == Phase.drawing) Sfx.play(Snd.timeup);
      case Ev.results:
        break;
      case Ev.over:
        _recordGame();
      case Ev.joined:
        Sfx.play(Snd.join);
        showToast(context, '${e.name} اومد!', icon: '👋', color: C.panel2, fg: C.txt);
      case Ev.left:
        break;
      case Ev.reconnecting:
        Sfx.medium();
      case Ev.reconnected:
        showToast(context, 'دوباره وصل شدی', icon: '📶');
    }
  }

  void _recordGame() {
    final me = c.me;
    if (me == null || _gain != null) return;
    final team = c.mode == 'team';
    final won = team ? c.winnerTeam == me.team : c.winnerId == c.myId;
    final points = team ? c.teamScore[me.team] : me.score;
    _gain = Progress.onlineGame(myPoints: points, won: won, solves: c.mySolves, drawnSolves: c.myDrawingsSolved);
    if (won) {
      Sfx.play(Snd.win);
      Sfx.heavy();
      setState(() => _confetti++);
    } else {
      Sfx.play(Snd.end);
    }
  }

  Future<void> _connectionLost(String why) async {
    Sfx.play(Snd.timeup);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('از بازی بیرون اومدی', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Text(why, style: const TextStyle(color: C.txtDim, height: 1.7)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('برگرد به خونه'))],
        ),
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<bool> _confirmLeave() async {
    if (c.phase == Phase.over || c.phase == Phase.lobby && c.players.length <= 1) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('از بازی خارج می‌شی؟', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('بقیه بدون تو ادامه می‌دن.', style: TextStyle(color: C.txtDim)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('می‌مونم')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج', style: TextStyle(color: C.anar))),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _leave() async {
    if (!await _confirmLeave()) return;
    _lostShown = true;
    c.leave();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: DoodleBackground(
          opacity: c.phase == Phase.drawing || c.phase == Phase.stealing ? 0 : .07,
          child: SafeArea(
            child: Stack(children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: child),
                  ),
                  child: KeyedSubtree(key: ValueKey(_screenKey), child: _body()),
                ),
              ),
              Positioned.fill(child: Confetti(trigger: _confetti)),
              if (_popTrigger > 0) Positioned.fill(child: ScorePop(points: _popPoints, trigger: _popTrigger)),
              if (c.reconnecting) const Positioned.fill(child: _Reconnecting()),
            ]),
          ),
        ),
      ),
    );
  }

  String get _screenKey => switch (c.phase) {
        Phase.idle || Phase.lobby => 'lobby',
        Phase.choosing => c.wordChoices.isNotEmpty ? 'choose' : 'wait',
        Phase.drawing || Phase.stealing => c.iAmDrawer ? 'draw' : 'guess',
        Phase.results => 'results${c.turn}',
        Phase.over => 'over',
      };

  Widget _body() {
    switch (c.phase) {
      case Phase.idle:
      case Phase.lobby:
        return Column(children: [
          _topBar(c.roomCode != null ? 'اتاق خصوصی' : 'بازی عمومی'),
          Expanded(child: LobbyView(client: c)),
        ]);
      case Phase.choosing:
        return c.wordChoices.isNotEmpty ? _chooseWord() : _waiting();
      case Phase.drawing:
      case Phase.stealing:
        return c.iAmDrawer ? _drawView() : _guessView();
      case Phase.results:
        return _results();
      case Phase.over:
        return _gameOver();
    }
  }

  Widget _topBar(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(children: [
          IconButton(onPressed: _leave, icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'خروج'),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      );

  /* ---------------------------- waiting ---------------------------- */
  Widget _waiting() {
    final d = c.drawer;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _Bounce(child: AvatarBubble(d?.avatar ?? '🎨', size: 96, ring: C.zaferan, badge: '✏️')),
        const SizedBox(height: 18),
        Text('${c.drawerName} داره کلمه انتخاب می‌کنه…', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('نوبت ${fa(c.turn)} از ${fa(c.turns)}', style: const TextStyle(color: C.txtDim)),
        const SizedBox(height: 26),
        if (c.mode == 'team') TeamBar(score: c.teamScore, turnTeam: c.drawer?.team ?? 0) else _MiniBoard(client: c),
      ]),
    );
  }

  /* -------------------------- choose word -------------------------- */
  Widget _chooseWord() {
    const levels = ['آسون', 'متوسط', 'سخت'];
    const colors = [C.firuzeh, C.zaferan, C.anar];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Appear(child: Text('نوبت توئه! ✏️', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
        const SizedBox(height: 4),
        const Appear(delay: Duration(milliseconds: 80), child: Text('یکی رو انتخاب کن و بکش', style: TextStyle(color: C.txtDim, fontSize: 15))),
        const SizedBox(height: 22),
        for (var i = 0; i < c.wordChoices.length; i++)
          Appear(
            delay: stagger(i + 1, 110),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                label: '${c.wordChoices[i]} ${levels[i]}',
                excludeSemantics: true,
                child: Pressable(
                  sound: Snd.select,
                  onTap: () => c.pickWord(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: C.panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colors[i].withValues(alpha: .5), width: 1.6),
                      boxShadow: [BoxShadow(color: colors[i].withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Row(children: [
                      Expanded(child: Text(c.wordChoices[i], style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: colors[i].withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                        child: Text(levels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: colors[i])),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Appear(delay: stagger(4, 110), child: GhostButton('رد کردن نوبت (بدون امتیاز)', onTap: c.skipWord)),
      ]),
    );
  }

  /* ----------------------------- header ---------------------------- */
  Widget _hud({required Widget middle, required Color ringColor}) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          TimerRing(seconds: c.secondsLeft, total: c.clockTotal, color: ringColor),
          const SizedBox(width: 10),
          Expanded(child: middle),
          const SizedBox(width: 10),
          Column(children: [
            const Text('نوبت', style: TextStyle(fontSize: 11, color: C.txtDim)),
            Text('${fa(c.turn)}/${fa(c.turns)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ]),
        ]),
      );

  /* ------------------------------ draw ----------------------------- */
  Widget _drawView() {
    return Column(children: [
      if (c.mode == 'team') TeamBar(score: c.teamScore, turnTeam: c.drawerTeam),
      _hud(
        ringColor: C.firuzeh,
        middle: Column(children: [
          const Text('داری این رو می‌کشی', style: TextStyle(fontSize: 11.5, color: C.txtDim)),
          Text(c.myWord ?? '', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: C.zaferan)),
        ]),
      ),
      PlayerStrip(client: c),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: DrawingSurface(
            model: c.board,
            enabled: true,
            color: _eraser ? C.kaghaz : _color,
            width: _eraser ? _width * 1.8 : _width,
            onPoints: c.strokePoints,
            onEnd: c.strokeEnd,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ToolTray(
          color: _color,
          width: _width,
          eraser: _eraser,
          onColor: (v) => setState(() => _color = v),
          onWidth: (v) => setState(() => _width = v),
          onEraser: (v) => setState(() => _eraser = v),
          onUndo: c.undo,
          onClear: c.clearCanvas,
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: SizedBox(height: 70, child: ChatFeed(lines: c.chat, compact: true))),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: SizedBox(width: 104, child: GameButton.saffron('تموم شد', onTap: c.doneDrawing)),
        ),
      ]),
      const SizedBox(height: 6),
    ]);
  }

  /* ----------------------------- guess ----------------------------- */
  Widget _guessView() {
    final canGuess = c.canGuess;
    return Column(children: [
      if (c.mode == 'team') TeamBar(score: c.teamScore, turnTeam: c.drawerTeam),
      if (c.stealOpen)
        Appear(
          from: const Offset(0, -.5),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: C.zaferan, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(
                canGuess ? '⚔️ ${fa(c.clockTotal)} ثانیه فرصت دزدیدن ${fa(c.stealPoints)} امتیاز!' : '⚔️ تیم مقابل داره سعی می‌کنه بدزده!',
                style: const TextStyle(color: C.onZaferan, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ),
      _hud(
        ringColor: C.zaferan,
        middle: Column(children: [
          Text(c.iSolved ? '🔒 حلش کردی!' : '${c.drawerName} داره می‌کشه',
              style: TextStyle(fontSize: 11.5, color: c.iSolved ? C.firuzeh : C.txtDim, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          if (c.iSolved && c.myWord != null)
            Text(c.myWord!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.zaferan))
          else
            MaskedWord(mask: c.mask),
        ]),
      ),
      PlayerStrip(client: c),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: DrawingSurface(model: c.board),
        ),
      ),
      SizedBox(height: 104, child: ChatFeed(lines: c.chat)),
      GuessBar(
        enabled: canGuess,
        hint: !canGuess
            ? (c.phase == Phase.stealing ? 'تیم مقابل داره می‌دزده…' : 'نوبت تیم مقابله — فقط تماشا کن')
            : c.iSolved
                ? 'پیامت فقط به حل‌کننده‌ها می‌رسه…'
                : (c.stealOpen ? 'زود باش، بدزدش!' : 'حدست رو بنویس…'),
        onSend: c.guess,
      ),
    ]);
  }

  /* ---------------------------- results ---------------------------- */
  Widget _results() {
    final team = c.mode == 'team';
    final drawer = c.players.where((p) => p.id == c.lastDrawerId).firstOrNull;
    final rows = [...c.players]..sort((a, b) => (c.gains[b.id] ?? 0).compareTo(c.gains[a.id] ?? 0));
    final nobody = c.gains.isEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      children: [
        Appear(
          child: Text(nobody ? 'کسی حدس نزد! 😅' : 'جواب این بود:',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: C.txtDim, fontWeight: FontWeight.w700)),
        ),
        if (c.revealedWord != null)
          Appear(
            scale: true,
            delay: const Duration(milliseconds: 120),
            child: Text(c.revealedWord!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w900, color: C.zaferan, shadows: [Shadow(color: Color(0x66F2A93B), blurRadius: 20)])),
          ),
        const SizedBox(height: 12),
        Appear(
          delay: const Duration(milliseconds: 220),
          child: Stack(children: [
            AspectRatio(aspectRatio: 1.15, child: DrawingSurface(model: c.board)),
            if (!c.board.isEmpty)
              PositionedDirectional(
                bottom: 10,
                start: 10,
                child: Pressable(
                  onTap: () => shareDrawing(context, c.board, word: c.revealedWord),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: C.lajvard.withValues(alpha: .85), borderRadius: BorderRadius.circular(20)),
                    child: const Text('📤 بفرست', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ),
            if (drawer != null)
              PositionedDirectional(
                top: 10,
                end: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: C.lajvard.withValues(alpha: .85), borderRadius: BorderRadius.circular(20)),
                  child: Text('${drawer.avatar} نقاشی ${drawer.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        if (team) TeamBar(score: c.teamScore, turnTeam: drawer?.team ?? 0),
        for (var i = 0; i < rows.length; i++)
          if (!team || (c.gains[rows[i].id] ?? 0) > 0)
            Appear(
              delay: stagger(i + 3),
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: rows[i].id == c.myId ? const Color(0x1A2AB5A6) : C.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rows[i].id == c.myId ? C.firuzeh : C.line),
                ),
                child: Row(children: [
                  Text(rows[i].avatar, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(rows[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  if ((c.gains[rows[i].id] ?? 0) > 0)
                    CountUp(c.gains[rows[i].id]!, prefix: '+', style: const TextStyle(color: C.firuzeh, fontWeight: FontWeight.w900, fontSize: 15)),
                  if (!team) ...[
                    const SizedBox(width: 12),
                    CountUp(rows[i].score,
                        from: rows[i].score - (c.gains[rows[i].id] ?? 0),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.zaferan)),
                  ],
                ]),
              ),
            ),
        const SizedBox(height: 10),
        if (!c.gameOver)
          const Column(children: [
            Text('نوبت بعد داره شروع می‌شه…', textAlign: TextAlign.center, style: TextStyle(color: C.txtDim, fontSize: 14)),
            SizedBox(height: 8),
            _CountdownBar(),
          ]),
      ],
    );
  }

  /* ---------------------------- game over ---------------------------- */
  Widget _gameOver() {
    final team = c.mode == 'team';
    final sorted = [...c.players]..sort((a, b) => b.score.compareTo(a.score));
    final me = c.me;
    final String title;
    if (team) {
      title = c.winnerTeam == null ? '🤝 مساوی شد!' : '🏆 تیم ${kTeamNames[c.winnerTeam!]} برد!';
    } else {
      title = sorted.isEmpty ? 'بازی تموم شد' : '🏆 ${sorted.first.id == c.myId ? 'تو بردی!' : '${sorted.first.name} برد!'}';
    }
    final mvp = c.players.where((p) => p.id == c.mvpId).firstOrNull;
    final gain = _gain;
    final lv = Progress.levelOf(Settings.I.xp);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Appear(scale: true, child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
        const SizedBox(height: 18),
        if (team)
          Row(children: [
            for (final t in [0, 1])
              Expanded(
                child: Appear(
                  delay: stagger(t + 1, 150),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: C.team(t).withValues(alpha: c.winnerTeam == t ? .3 : .12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: C.team(t), width: c.winnerTeam == t ? 3 : 1),
                    ),
                    child: Column(children: [
                      Text('تیم ${kTeamNames[t]}${c.winnerTeam == t ? ' 👑' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      CountUp(c.teamScore[t], duration: const Duration(milliseconds: 1500), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                      Text(c.players.where((p) => p.team == t).map((p) => p.avatar).join(' '), style: const TextStyle(fontSize: 18)),
                    ]),
                  ),
                ),
              ),
          ])
        else
          _Podium(players: sorted.take(3).toList(), myId: c.myId),
        if (mvp != null) ...[
          const SizedBox(height: 12),
          Appear(
            delay: stagger(4),
            child: Text('⭐ بهترین حدس‌زن: ${mvp.avatar} ${mvp.name}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: C.gold)),
          ),
        ],
        if (!team && sorted.length > 3)
          for (var i = 3; i < sorted.length; i++)
            Appear(
              delay: stagger(i + 2),
              child: Container(
                margin: const EdgeInsets.only(top: 7),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
                child: Row(children: [
                  SizedBox(width: 26, child: Text(fa(i + 1), style: const TextStyle(color: C.txtDim, fontWeight: FontWeight.w900))),
                  Text(sorted[i].avatar, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(sorted[i].name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(fa(sorted[i].score), style: const TextStyle(fontWeight: FontWeight.w900, color: C.zaferan)),
                ]),
              ),
            ),
        const SizedBox(height: 18),
        if (gain != null && me != null)
          Appear(
            delay: stagger(6),
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Text('✨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  CountUp(gain.xp, prefix: '+', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.zaferan)),
                  const Text(' تجربه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (gain.levelledUp)
                    const Text('سطح بالا رفتی! 🎉', style: TextStyle(fontWeight: FontWeight.w900, color: C.gold)),
                ]),
                const SizedBox(height: 10),
                LevelBar(level: lv.level, into: lv.into, need: lv.need),
                if (gain.unlocked.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('شکلک تازه باز شد: ${gain.unlocked.join(' ')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
        const SizedBox(height: 18),
        if (c.isHost)
          GameButton('بازی دوباره', icon: '🔁', big: true, onTap: () {
            _gain = null;
            c.playAgain();
          })
        else
          const Text('منتظر میزبان برای بازی دوباره…', textAlign: TextAlign.center, style: TextStyle(color: C.txtDim)),
        const SizedBox(height: 10),
        GhostButton('برگرد به خونه', icon: '🏠', onTap: () {
          _lostShown = true;
          c.leave();
          Navigator.of(context).pop();
        }),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.players, required this.myId});
  final List<Player> players;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    // order on screen: 2nd, 1st, 3rd (RTL: first child on the right)
    final slots = <(int, double, Color)>[(1, 110, C.silver), (0, 150, C.gold), (2, 80, C.bronze)];
    return SizedBox(
      height: 270,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (rank, h, color) in slots)
          Expanded(
            child: rank >= players.length
                ? const SizedBox.shrink()
                : Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Appear(
                      delay: Duration(milliseconds: 700 + (2 - rank) * 250),
                      scale: true,
                      child: AvatarBubble(players[rank].avatar, size: rank == 0 ? 66 : 54, ring: color, badge: rank == 0 ? '👑' : null),
                    ),
                    const SizedBox(height: 4),
                    Text(players[rank].id == myId ? 'تو' : players[rank].name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: h),
                      duration: Duration(milliseconds: 700 + (2 - rank) * 250),
                      curve: Curves.easeOutBack,
                      builder: (_, v, child) => Container(
                        height: v.clamp(0, 200),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: .55)]),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 8),
                        child: child,
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(fa(rank + 1), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: C.lajvard)),
                        CountUp(players[rank].score, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: C.lajvard)),
                      ]),
                    ),
                  ]),
          ),
      ]),
    );
  }
}

/// Small scoreboard shown while waiting for the drawer.
class _MiniBoard extends StatelessWidget {
  const _MiniBoard({required this.client});
  final GameClient client;
  @override
  Widget build(BuildContext context) {
    final sorted = [...client.players]..sort((a, b) => b.score.compareTo(a.score));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(children: [
        for (final p in sorted.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text(p.avatar, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(p.id == client.myId ? 'تو' : p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(fa(p.score), style: const TextStyle(color: C.zaferan, fontWeight: FontWeight.w900)),
            ]),
          ),
      ]),
    );
  }
}

class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});
  final Widget child;
  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(0, -10 * Curves.easeInOut.transform(_c.value)), child: child),
        child: widget.child,
      );
}

class _CountdownBar extends StatelessWidget {
  const _CountdownBar();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(seconds: 5),
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: C.panel2, valueColor: const AlwaysStoppedAnimation(C.firuzeh)),
          ),
        ),
      );
}

class _Reconnecting extends StatelessWidget {
  const _Reconnecting();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xCC0B1730),
        child: Center(
          child: Panel(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('📶', style: TextStyle(fontSize: 40)),
              SizedBox(height: 8),
              Text('ارتباط قطع شد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('داریم دوباره وصلت می‌کنیم — جات نگه داشته شده', style: TextStyle(color: C.txtDim)),
              SizedBox(height: 14),
              CircularProgressIndicator(color: C.firuzeh),
            ]),
          ),
        ),
      );
}
