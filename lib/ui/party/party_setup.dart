import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../party/party_rules.dart';
import '../../theme.dart';
import '../fx.dart';
import '../widgets.dart';
import 'party_game.dart';

class PartySetupScreen extends StatefulWidget {
  const PartySetupScreen({super.key});
  @override
  State<PartySetupScreen> createState() => _PartySetupScreenState();
}

class _PartySetupScreenState extends State<PartySetupScreen> {
  late final _a = TextEditingController(text: Settings.I.partyTeams[0]);
  late final _b = TextEditingController(text: Settings.I.partyTeams[1]);
  PartyMode _mode = PartyMode.draw;
  int _turns = 3;
  int _seconds = 60;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _start() {
    final names = [
      _a.text.trim().isEmpty ? 'تیم آبی' : _a.text.trim(),
      _b.text.trim().isEmpty ? 'تیم قرمز' : _b.text.trim(),
    ];
    Settings.I.partyTeams = names;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PartyGameScreen(game: PartyGame(teams: names, turnsPerTeam: _turns, turnSeconds: _seconds, mode: _mode)),
    ));
  }

  Widget _team(TextEditingController c, int t) => Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: C.team(t).withValues(alpha: .25), shape: BoxShape.circle, border: Border.all(color: C.team(t), width: 2.4)),
          child: Text(t == 0 ? '🔵' : '🔴', style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(controller: c, maxLength: 16, decoration: const InputDecoration(counterText: '')),
        ),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DoodleBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward_rounded)),
                  const Text('دورهمی 🎉', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ]),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Text(
                    'دو تیم، یک گوشی. نوبت هر تیم که بشه، یکی گوشی رو می‌گیره، کلمه رو می‌بینه و می‌کشه یا ادا درمیاره. هم‌تیمی‌هاش بلند حدس می‌زنن!',
                    style: TextStyle(color: C.txtDim, height: 1.8, fontSize: 14),
                  ),
                ),
                Appear(
                  child: Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('تیم‌ها'),
                      _team(_a, 0),
                      const SizedBox(height: 10),
                      _team(_b, 1),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Appear(
                  delay: stagger(1),
                  child: Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('نوع بازی'),
                      Row(children: [
                        Expanded(child: ChoiceChipX('🖌️ نقاشی', on: _mode == PartyMode.draw, onTap: () => setState(() => _mode = PartyMode.draw))),
                        const SizedBox(width: 8),
                        Expanded(child: ChoiceChipX('🎭 پانتومیم', on: _mode == PartyMode.mime, onTap: () => setState(() => _mode = PartyMode.mime))),
                      ]),
                      const SizedBox(height: 6),
                      Text(_mode == PartyMode.draw ? 'روی گوشی می‌کشی، بقیه نگاه می‌کنن.' : 'بدون حرف زدن ادا درمیاری! گوشی فقط کلمه و زمان رو نشون می‌ده.',
                          style: const TextStyle(color: C.txtDim, fontSize: 12.5)),
                      const SizedBox(height: 14),
                      const SectionTitle('نوبت برای هر تیم'),
                      Row(children: [
                        for (final n in [3, 5, 7])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: ChoiceChipX(fa(n), on: _turns == n, color: C.zaferan, onTap: () => setState(() => _turns = n)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      const SectionTitle('زمان هر نوبت'),
                      Row(children: [
                        for (final s in [45, 60, 90])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: ChoiceChipX('${fa(s)} ثانیه', on: _seconds == s, color: C.zaferan, onTap: () => setState(() => _seconds = s)),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 22),
                Appear(delay: stagger(2), child: GameButton.saffron('شروع دورهمی', icon: '🎉', big: true, onTap: _start)),
              ],
            ),
          ),
        ),
      );
}
