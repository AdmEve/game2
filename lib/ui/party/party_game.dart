import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/progress.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/words.dart';
import '../../draw/board.dart';
import '../../party/party_rules.dart';
import '../../theme.dart';
import '../fx.dart';
import '../share.dart';
import '../widgets.dart';
import 'party_setup.dart';

class PartyGameScreen extends StatefulWidget {
  const PartyGameScreen({super.key, required this.game});
  final PartyGame game;

  @override
  State<PartyGameScreen> createState() => _PartyGameScreenState();
}

class _PartyGameScreenState extends State<PartyGameScreen> {
  PartyGame get g => widget.game;
  WordBank? _bank;
  final _board = BoardModel();
  Color _color = C.ink;
  double _width = kBrushSizes[1];
  bool _eraser = false;
  bool _hideWord = false;

  Timer? _timer;
  int _left = 0;
  int _total = 0;
  int _confetti = 0;
  int _pop = 0;
  int _popPts = 0;
  Gain? _gain;

  @override
  void initState() {
    super.initState();
    WordBank.load().then((b) {
      if (mounted) setState(() => _bank = b);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _board.dispose();
    super.dispose();
  }

  List<String> _fresh() {
    final avoid = {...Settings.I.recentWords, ...g.choices};
    final words = _bank!.choices(avoid);
    Settings.I.rememberWords(words);
    return words;
  }

  void _clock(int seconds, VoidCallback onEnd) {
    _timer?.cancel();
    _left = seconds;
    _total = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left--);
      if (_left <= 5 && _left > 0) {
        Sfx.play(Snd.tick);
        if (_left <= 3) Sfx.tick();
      }
      if (_left <= 0) {
        t.cancel();
        onEnd();
      }
    });
  }

  /* ---- flow ---- */
  void _reveal() {
    if (_bank == null) return;
    setState(() => g.offer(_fresh()));
  }

  void _pick(int i) {
    Sfx.play(Snd.turn);
    Sfx.medium();
    _board.clear();
    _eraser = false;
    _hideWord = false;
    setState(() => g.pick(i));
    _clock(g.turnSeconds, () {
      Sfx.play(Snd.timeup);
      Sfx.heavy();
      _openSteal();
    });
  }

  void _gotIt() {
    _timer?.cancel();
    final pts = g.solved(_left);
    Sfx.play(Snd.correct);
    Sfx.heavy();
    setState(() {
      _confetti++;
      _popPts = pts;
      _pop++;
    });
  }

  void _openSteal() {
    _timer?.cancel();
    setState(g.openSteal);
    Sfx.play(Snd.steal);
    _clock(stealSeconds, () => setState(() {}));
  }

  void _stealDone(bool ok) {
    _timer?.cancel();
    final pts = g.stealResult(ok);
    if (ok) {
      Sfx.play(Snd.correct);
      setState(() {
        _confetti++;
        _popPts = pts;
        _pop++;
      });
    } else {
      Sfx.play(Snd.end);
      setState(() {});
    }
  }

  void _next() {
    setState(g.next);
    if (g.stage == PartyStage.over) {
      _gain = Progress.partyGame(wordsGuessed: g.wordsGuessed);
      Sfx.play(Snd.win);
      Sfx.heavy();
      setState(() => _confetti++);
    } else {
      Sfx.play(Snd.select);
    }
  }

  Future<bool> _confirmQuit() async {
    if (g.stage == PartyStage.over) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('دورهمی رو تموم کنیم؟', style: TextStyle(fontWeight: FontWeight.w900)),
          content: const Text('امتیازهای این بازی از بین می‌ره.', style: TextStyle(color: C.txtDim)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ادامه')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تموم کن', style: TextStyle(color: C.anar))),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (await _confirmQuit() && context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          body: DoodleBackground(
            opacity: g.stage == PartyStage.play ? 0 : .08,
            child: SafeArea(
              child: Stack(children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(a), child: child),
                    ),
                    child: KeyedSubtree(key: ValueKey('${g.stage}-${g.turnIndex}'), child: _body()),
                  ),
                ),
                Positioned.fill(child: Confetti(trigger: _confetti)),
                if (_pop > 0) Positioned.fill(child: ScorePop(points: _popPts, trigger: _pop)),
              ]),
            ),
          ),
        ),
      );

  Widget _body() => switch (g.stage) {
        PartyStage.pass => _pass(),
        PartyStage.choose => _choose(),
        PartyStage.play => g.mode == PartyMode.draw ? _draw() : _mime(),
        PartyStage.steal => _steal(),
        PartyStage.result => _result(),
        PartyStage.over => _over(),
      };

  Widget _scores() => TeamBar(score: g.scores, turnTeam: g.team, names: g.teams);

  /* ---- pass the phone ---- */
  Widget _pass() {
    final col = C.team(g.team);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: const Alignment(0, -.3), radius: 1.1, colors: [col.withValues(alpha: .45), Colors.transparent]),
      ),
      child: Column(children: [
        _scores(),
        const Spacer(),
        Appear(child: Text('دور ${fa(g.round)} از ${fa(g.turnsPerTeam)}', style: const TextStyle(color: C.txtDim, fontSize: 15))),
        const SizedBox(height: 6),
        Appear(
          scale: true,
          delay: const Duration(milliseconds: 100),
          child: Text('نوبت ${g.teams[g.team]}', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: col)),
        ),
        const SizedBox(height: 14),
        Appear(
          delay: const Duration(milliseconds: 200),
          child: Text(g.mode == PartyMode.draw ? '📱 گوشی رو بده به نقاش تیم' : '📱 گوشی رو بده به بازیگر تیم',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        const Appear(
          delay: Duration(milliseconds: 250),
          child: Text('بقیه صفحه رو نبینن!', style: TextStyle(color: C.txtDim)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: GameButton.saffron(
            _bank == null ? 'یه لحظه…' : (g.mode == PartyMode.draw ? 'من نقاشم — کلمه رو نشونم بده' : 'من بازیگرم — کلمه رو نشونم بده'),
            icon: '👀',
            big: true,
            onTap: _bank == null ? null : _reveal,
          ),
        ),
      ]),
    );
  }

  /* ---- choose ---- */
  Widget _choose() {
    const levels = ['آسون', 'متوسط', 'سخت'];
    const colors = [C.firuzeh, C.zaferan, C.anar];
    final hint = g.mode == PartyMode.draw ? 'یکی رو انتخاب کن — نوشتن ممنوع!' : 'یکی رو انتخاب کن — حرف زدن ممنوع!';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(hint, style: const TextStyle(color: C.txtDim, fontSize: 15)),
        const SizedBox(height: 18),
        for (var i = 0; i < g.choices.length; i++)
          Appear(
            key: ValueKey(g.choices[i]),
            delay: stagger(i, 100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                label: '${g.choices[i]} ${levels[i]}',
                excludeSemantics: true,
                child: Pressable(
                  sound: Snd.select,
                  onTap: () => _pick(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: C.panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colors[i].withValues(alpha: .5), width: 1.6),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g.choices[i], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                          Text(_bank?.categoryOf[g.choices[i]] ?? '', style: const TextStyle(fontSize: 12, color: C.txtDim)),
                        ]),
                      ),
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
        GhostButton(g.canReshuffle ? 'کلمه‌های دیگه (یک بار)' : 'کلمه‌ها عوض شدن', icon: '🔀',
            onTap: g.canReshuffle ? () => setState(() => g.reshuffle(_fresh())) : null),
      ]),
    );
  }

  /* ---- play: draw ---- */
  Widget _wordBadge() => Semantics(
        button: true,
        label: _hideWord ? 'نشون دادن کلمه' : 'پنهان کردن کلمه',
        child: Pressable(
          onTap: () => setState(() => _hideWord = !_hideWord),
          child: Column(children: [
            Text(_hideWord ? 'کلمه پنهانه — بزن تا ببینی' : '${g.teams[g.team]} · بزن تا پنهان بشه',
                style: const TextStyle(fontSize: 11, color: C.txtDim)),
            Text(_hideWord ? '••••' : g.word!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.zaferan)),
          ]),
        ),
      );

  Widget _playButtons() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(children: [
          Expanded(flex: 3, child: GameButton('گرفتن! ✓', big: true, sound: null, onTap: _gotIt)),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: GameButton.danger('تسلیم', onTap: _openSteal)),
        ]),
      );

  Widget _draw() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            TimerRing(seconds: _left, total: _total, color: C.team(g.team)),
            const SizedBox(width: 10),
            Expanded(child: _wordBadge()),
            const SizedBox(width: 10),
            Column(children: [
              Text(fa(g.scores[g.team]), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: C.team(g.team))),
              const Text('امتیاز', style: TextStyle(fontSize: 10.5, color: C.txtDim)),
            ]),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: DrawingSurface(
              model: _board,
              enabled: true,
              color: _eraser ? C.kaghaz : _color,
              width: _eraser ? _width * 1.8 : _width,
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
            onUndo: _board.removeLast,
            onClear: _board.clear,
          ),
        ),
        _playButtons(),
      ]);

  /* ---- play: mime ---- */
  Widget _mime() => Column(children: [
        _scores(),
        const Spacer(),
        TimerRing(seconds: _left, total: _total, color: C.team(g.team), size: 110),
        const SizedBox(height: 26),
        Pressable(
          onTap: () => setState(() => _hideWord = !_hideWord),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 26),
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
            decoration: BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.team(g.team), width: 2.4),
            ),
            child: Column(children: [
              Text(_hideWord ? '••••' : g.word!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: C.zaferan)),
              const SizedBox(height: 4),
              Text(_hideWord ? 'بزن تا ببینی' : (_bank?.categoryOf[g.word] ?? ''), style: const TextStyle(color: C.txtDim)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('🤫 بدون حرف زدن ادا دربیار!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const Spacer(),
        _playButtons(),
      ]);

  /* ---- steal ---- */
  Widget _steal() {
    final col = C.team(g.otherTeam);
    final over = _left <= 0;
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: const Alignment(0, -.2), radius: 1.1, colors: [col.withValues(alpha: .4), Colors.transparent]),
      ),
      child: Column(children: [
        _scores(),
        if (g.mode == PartyMode.draw)
          Expanded(
            flex: 3,
            child: Padding(padding: const EdgeInsets.all(12), child: DrawingSurface(model: _board)),
          ),
        if (g.mode == PartyMode.mime) const Spacer(),
        Appear(
          scale: true,
          child: Text('⚔️ ${g.teams[g.otherTeam]}، بدزد!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: col)),
        ),
        const SizedBox(height: 6),
        Text(over ? 'وقت تموم شد — گرفتن؟' : '${fa(stealSeconds)} ثانیه وقت دارید، یک حدس، ${fa(stealPoints)} امتیاز',
            style: const TextStyle(color: C.txtDim)),
        const SizedBox(height: 12),
        TimerRing(seconds: _left, total: _total, color: col, size: 70),
        if (g.mode == PartyMode.mime) const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Row(children: [
            Expanded(flex: 3, child: GameButton.saffron('دزدیدن! ✓', big: true, onTap: () => _stealDone(true))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: GameButton.danger('نتونستن', onTap: () => _stealDone(false))),
          ]),
        ),
      ]),
    );
  }

  /* ---- result ---- */
  Widget _result() {
    final o = g.last!;
    final text = switch (o.byTeam) {
      null => 'کسی نگرفت 😅',
      final t when t == o.team => '${g.teams[t]} گرفت! +${fa(o.points)}',
      final t => '${g.teams[t]} دزدید! +${fa(o.points)}',
    };
    return ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
      _scores(),
      const SizedBox(height: 18),
      const Text('کلمه این بود:', textAlign: TextAlign.center, style: TextStyle(color: C.txtDim, fontSize: 15)),
      Appear(
        scale: true,
        child: Text(o.word, textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: C.zaferan)),
      ),
      const SizedBox(height: 6),
      Appear(
        delay: const Duration(milliseconds: 150),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: o.byTeam == null ? C.txtDim : C.team(o.byTeam!))),
      ),
      if (g.mode == PartyMode.draw && !_board.isEmpty) ...[
        const SizedBox(height: 14),
        Stack(children: [
          AspectRatio(aspectRatio: 1.2, child: DrawingSurface(model: _board)),
          PositionedDirectional(
            bottom: 10,
            start: 10,
            child: Pressable(
              onTap: () => shareDrawing(context, _board, word: o.word),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: C.lajvard.withValues(alpha: .85), borderRadius: BorderRadius.circular(20)),
                child: const Text('📤 بفرست', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
          ),
        ]),
      ],
      const SizedBox(height: 20),
      GameButton(g.turnIndex + 1 >= g.totalTurns ? 'نتیجه‌ی نهایی' : 'نوبت بعد', icon: '➡️', big: true, onTap: _next),
    ]);
  }

  /* ---- over ---- */
  Widget _over() {
    final w = g.winner;
    final gain = _gain;
    final lv = Progress.levelOf(Settings.I.xp);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 30, 20, 24), children: [
      Appear(
        scale: true,
        child: Text(w == null ? '🤝 مساوی شد!' : '🏆 ${g.teams[w]} برد!',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: w == null ? C.txt : C.team(w))),
      ),
      const SizedBox(height: 20),
      Row(children: [
        for (final t in [0, 1])
          Expanded(
            child: Appear(
              delay: stagger(t + 1, 150),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: C.team(t).withValues(alpha: w == t ? .3 : .12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: C.team(t), width: w == t ? 3 : 1),
                ),
                child: Column(children: [
                  Text('${g.teams[t]}${w == t ? ' 👑' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  CountUp(g.scores[t], duration: const Duration(milliseconds: 1500), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      Text('${fa(g.wordsGuessed)} کلمه از ${fa(g.totalTurns)} گرفته شد', textAlign: TextAlign.center, style: const TextStyle(color: C.txtDim)),
      const SizedBox(height: 18),
      if (gain != null)
        Appear(
          delay: stagger(4),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Text('✨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                CountUp(gain.xp, prefix: '+', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.zaferan)),
                const Text(' تجربه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (gain.levelledUp) const Text('سطح بالا رفتی! 🎉', style: TextStyle(fontWeight: FontWeight.w900, color: C.gold)),
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
      const SizedBox(height: 20),
      GameButton.saffron('یه دست دیگه', icon: '🔁', big: true, onTap: () {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PartyGameScreen(game: PartyGame(teams: g.teams, turnsPerTeam: g.turnsPerTeam, turnSeconds: g.turnSeconds, mode: g.mode)),
        ));
      }),
      const SizedBox(height: 10),
      GhostButton('تنظیمات دورهمی', icon: '⚙️', onTap: () {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PartySetupScreen()));
      }),
      const SizedBox(height: 10),
      GhostButton('برگرد به خونه', icon: '🏠', onTap: () => Navigator.of(context).pop()),
    ]);
  }
}
