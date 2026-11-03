import 'package:flutter/material.dart';

import '../net/game_client.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.client});
  final GameClient client;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _guess = TextEditingController();
  Color _color = C.ink;
  double _width = kBrushSizes[1];
  String? _shownError;
  bool _lostShown = false;

  GameClient get c => widget.client;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    if (!c.connected && c.phase != Phase.over && !_lostShown) {
      _lostShown = true;
      _shownError = c.error;
      _connectionLost(c.error ?? 'ارتباط با سرور قطع شد');
    } else if (c.error != null && c.error != _shownError) {
      _shownError = c.error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(c.error!), backgroundColor: C.anar));
    }
    setState(() {});
  }

  Future<void> _connectionLost(String why) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: C.panel,
          title: const Text('از بازی بیرون اومدی', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text(why, style: const TextStyle(color: C.txtDim, height: 1.7)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('برگرد به خونه')),
          ],
        ),
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    c.dispose();
    _guess.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (c.phase) {
      case Phase.idle:
      case Phase.lobby:
        return LobbyView(client: c);
      case Phase.choosing:
        return c.wordChoices.isNotEmpty ? _chooseWord() : _waiting();
      case Phase.drawing:
      case Phase.stealing:
        return c.iAmDrawer ? _drawView() : _guessView();
      case Phase.results:
      case Phase.over:
        return _results();
    }
  }

  /* ---------------------------- waiting ---------------------------- */
  Widget _waiting() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: C.firuzeh),
          const SizedBox(height: 18),
          Text('${c.drawerName} داره کلمه انتخاب می‌کنه…',
              style: const TextStyle(color: C.txtDim, fontSize: 15)),
        ]),
      );

  /* -------------------------- choose word -------------------------- */
  Widget _chooseWord() {
    const levels = ['آسون', 'متوسط', 'سخت'];
    const colors = [C.firuzeh, C.zaferan, C.anar];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('نوبت توئه',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('یکی رو انتخاب کن و بکش',
            style: TextStyle(color: C.txtDim, fontSize: 14)),
        const SizedBox(height: 18),
        ...List.generate(c.wordChoices.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => c.pickWord(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                    color: C.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: C.line)),
                child: Row(children: [
                  Expanded(
                      child: Text(c.wordChoices[i],
                          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: colors[i].withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(levels[i],
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: colors[i])),
                  ),
                ]),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        GhostButton('رد کردن نوبت (بدون امتیاز)', onTap: c.skipWord),
      ]),
    );
  }

  /* ----------------------------- header ---------------------------- */
  Widget _topBar({required Widget middle, required Color ringColor}) {
    final total = c.clockTotal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: C.panel,
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(children: [
        TimerRing(seconds: c.secondsLeft, total: total, color: ringColor),
        const SizedBox(width: 12),
        Expanded(child: middle),
        const SizedBox(width: 12),
        Column(children: [
          const Text('نوبت', style: TextStyle(fontSize: 11, color: C.txtDim)),
          Text('${fa(c.turn)}/${fa(c.turns)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  /* ------------------------------ draw ----------------------------- */
  Widget _drawView() {
    return Column(children: [
      if (c.mode == 'team') TeamBar(score: c.teamScore, turnTeam: c.drawerTeam),
      _topBar(
        ringColor: C.firuzeh,
        middle: Column(children: [
          const Text('داری این رو می‌کشی', style: TextStyle(fontSize: 11, color: C.txtDim)),
          const SizedBox(height: 3),
          Text(c.myWord ?? '',
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w900, color: C.zaferan)),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Expanded(
              child: DrawBoard(
                strokes: c.strokes,
                enabled: true,
                color: _color,
                width: _width,
                onStrokeDone: c.sendStroke,
              ),
            ),
            const SizedBox(height: 10),
            _tools(),
          ]),
        ),
      ),
      if (c.voiceAllowed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PushToTalk(
            enabled: c.micAllowed,
            label: c.micAllowed ? '🎙 نگه دار و حرف بزن' : '🔇 نقاش حق حرف زدن نداره',
          ),
        ),
      SizedBox(height: 120, child: ChatFeed(lines: c.chat)),
    ]);
  }

  Widget _tools() {
    return Column(children: [
      Row(children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kPalette
                .map((col) => GestureDetector(
                      onTap: () => setState(() => _color = col),
                      child: Container(
                        width: 29,
                        height: 29,
                        decoration: BoxDecoration(
                          color: col,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                              color: col == _color ? C.txt : Colors.transparent, width: 2),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        IconButton(
            onPressed: c.clearCanvas,
            icon: const Icon(Icons.delete_outline, color: C.txt)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        ...kBrushSizes.map((s) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () => setState(() => _width = s),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: s == _width ? C.firuzeh : C.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: s == _width ? C.firuzeh : C.line)),
                  child: Container(
                    width: s.clamp(3, 18),
                    height: s.clamp(3, 18),
                    decoration: BoxDecoration(
                        color: s == _width ? const Color(0xFF06231F) : C.txt,
                        shape: BoxShape.circle),
                  ),
                ),
              ),
            )),
        const Spacer(),
        SizedBox(width: 110, child: GhostButton('تمومه', onTap: c.doneDrawing)),
      ]),
    ]);
  }

  /* ----------------------------- guess ----------------------------- */
  Widget _guessView() {
    final canGuess = c.canGuess;
    return Column(children: [
      if (c.mode == 'team') TeamBar(score: c.teamScore, turnTeam: c.drawerTeam),
      if (c.stealOpen)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: C.zaferan,
          alignment: Alignment.center,
          child: Text('${fa(c.clockTotal)} ثانیه فرصت دزدیدن امتیاز!',
              style: const TextStyle(
                  color: Color(0xFF3A2600), fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      _topBar(
        ringColor: C.zaferan,
        middle: Column(children: [
          Text(c.iSolved ? '🔒 حلش کردی!' : '${c.drawerName} داره می‌کشه',
              style: TextStyle(
                  fontSize: 11,
                  color: c.iSolved ? C.firuzeh : C.txtDim,
                  fontWeight: c.iSolved ? FontWeight.w800 : FontWeight.w400)),
          const SizedBox(height: 3),
          if (c.iSolved && c.myWord != null)
            Text(c.myWord!,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w900, color: C.zaferan))
          else
            MaskedWord(mask: c.mask),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DrawBoard(strokes: c.strokes),
        ),
      ),
      SizedBox(height: 120, child: ChatFeed(lines: c.chat)),
      if (!c.voiceAllowed)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text('بازی عمومی — گفتگوی صوتی خاموشه.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: C.txtDim)),
        ),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
            color: C.panel, border: Border(top: BorderSide(color: C.line))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _guess,
              enabled: canGuess,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: !canGuess
                    ? 'نوبت تیم مقابله — فقط تماشا کن'
                    : c.iSolved
                        ? 'پیامت فقط به حل‌کننده‌ها می‌رسه…'
                        : (c.stealOpen ? 'زود باش، بدزدش!' : 'حدست رو بنویس…'),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: Material(
              color: canGuess ? C.firuzeh : C.panel2,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: canGuess ? _submit : null,
                child: const Icon(Icons.send, color: Color(0xFF06231F), size: 20),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  void _submit() {
    final t = _guess.text.trim();
    if (t.isEmpty) return;
    c.guess(t);
    _guess.clear();
  }

  /* ---------------------------- results ---------------------------- */
  Widget _results() {
    final team = c.mode == 'team';
    final sorted = [...c.players]..sort((a, b) => b.score.compareTo(a.score));
    String title;
    if (c.phase == Phase.over) {
      title = team
          ? (c.winnerTeam == null ? '🤝 مساوی!' : '🏆 برد تیم ${c.winnerTeam == 0 ? 'آبی' : 'قرمز'}')
          : '🏆 برنده: ${sorted.first.name}';
    } else {
      title = 'نوبت ${fa(c.turn)} از ${fa(c.turns)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (c.revealedWord != null)
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Vazirmatn', color: C.txtDim, fontSize: 15),
              children: [
                const TextSpan(text: 'جواب: '),
                TextSpan(
                    text: c.revealedWord,
                    style: const TextStyle(
                        color: C.zaferan, fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        const SizedBox(height: 18),
        if (team)
          ...List.generate(2, (t) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t == 0 ? C.teamA : C.teamB),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('تیم ${t == 0 ? 'آبی' : 'قرمز'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      c.players.where((p) => p.team == t).map((p) => '${p.avatar} ${p.name}').join(' · '),
                      style: const TextStyle(color: C.txtDim, fontSize: 12),
                    ),
                  ]),
                ),
                Text(fa(c.teamScore[t]),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, color: C.zaferan)),
              ]),
            );
          })
        else
          ...sorted.asMap().entries.map((e) {
            final p = e.value;
            final gain = c.gains[p.id];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: p.id == c.myId ? const Color(0x1A2AB5A6) : C.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.id == c.myId ? C.firuzeh : C.line),
              ),
              child: Row(children: [
                SizedBox(
                    width: 24,
                    child: Text(fa(e.key + 1),
                        style: const TextStyle(
                            color: C.txtDim, fontWeight: FontWeight.w900, fontSize: 15))),
                Text(p.avatar, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (gain != null && gain > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('+${fa(gain)}',
                        style: const TextStyle(
                            color: C.firuzeh, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                Text(fa(p.score),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900, color: C.zaferan)),
              ]),
            );
          }),
        const SizedBox(height: 14),
        if (c.phase == Phase.over)
          PrimaryButton('برگرد به خونه',
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst))
        else
          const Text('نوبت بعد داره شروع می‌شه…',
              style: TextStyle(color: C.txtDim, fontSize: 14)),
      ]),
    );
  }
}
