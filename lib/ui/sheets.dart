import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/progress.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import '../theme.dart';
import 'fx.dart';
import 'widgets.dart';

/// Opens a bottom sheet in the game's style.
Future<T?> showGameSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  Sfx.play(Snd.select);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.panel,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(top: false, child: builder(ctx)),
      ),
    ),
  );
}

/* ------------------------------ avatars ------------------------------ */

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key, required this.selected, required this.onPick, this.level});
  final String selected;
  final ValueChanged<String> onPick;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final lv = level ?? Progress.levelOf(Settings.I.xp).level;
    return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      for (final (a, need) in Progress.avatars)
        Semantics(
          label: need > lv ? 'قفل تا سطح ${fa(need)}' : 'آواتار',
          selected: a == selected,
          button: true,
          excludeSemantics: true,
          child: Pressable(
            sound: Snd.select,
            onTap: need > lv ? null : () => onPick(a),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: a == selected ? const Color(0x332AB5A6) : C.panel2,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: a == selected ? C.firuzeh : Colors.transparent, width: 2.4),
              ),
              child: need > lv
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Opacity(opacity: .25, child: Text(a, style: const TextStyle(fontSize: 20))),
                      Text('🔒${fa(need)}', style: const TextStyle(fontSize: 9.5, color: C.txtDim, fontWeight: FontWeight.w800)),
                    ])
                  : Text(a, style: const TextStyle(fontSize: 25)),
            ),
          ),
        ),
    ]);
  }
}

/* ------------------------------ first run ------------------------------ */

/// Full-screen welcome: just a name and an avatar.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController(text: Settings.I.name);
  String _avatar = Settings.I.avatar;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _go() {
    final s = Settings.I;
    s.name = _name.text.trim().isEmpty ? 'بازیکن' : _name.text.trim();
    s.avatar = _avatar;
    s.onboarded = true;
    Sfx.play(Snd.correct);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DoodleBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Appear(child: Center(child: Logo(size: 44))),
                  const SizedBox(height: 10),
                  const Appear(
                    delay: Duration(milliseconds: 150),
                    child: Text('خوش اومدی! یکی می‌کشه، بقیه حدس می‌زنن.',
                        textAlign: TextAlign.center, style: TextStyle(color: C.txtDim, fontSize: 15, height: 1.7)),
                  ),
                  const SizedBox(height: 26),
                  Appear(
                    delay: const Duration(milliseconds: 300),
                    child: Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SectionTitle('اسمت چیه؟'),
                        TextField(
                          controller: _name,
                          maxLength: 14,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(hintText: 'مثلاً پویا', counterText: ''),
                        ),
                        const SizedBox(height: 16),
                        const SectionTitle('یه شکلک انتخاب کن'),
                        AvatarPicker(selected: _avatar, onPick: (a) => setState(() => _avatar = a)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Appear(delay: const Duration(milliseconds: 450), child: GameButton('بزن بریم!', icon: '🚀', big: true, onTap: _go)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/* ------------------------------ profile ------------------------------ */

void showProfileSheet(BuildContext context) => showGameSheet(context, (_) => const _ProfileSheet());

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final _name = TextEditingController(text: Settings.I.name);

  @override
  void dispose() {
    final n = _name.text.trim();
    if (n.isNotEmpty) Settings.I.name = n;
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    final lv = Progress.levelOf(s.xp);
    Widget stat(String label, int v, String icon) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: C.panel2, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              Text(fa(v), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.zaferan)),
              Text(label, style: const TextStyle(fontSize: 11, color: C.txtDim, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AvatarBubble(s.avatar, size: 60, ring: C.zaferan),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _name,
              maxLength: 14,
              decoration: const InputDecoration(counterText: '', hintText: 'اسمت'),
              onSubmitted: (v) => s.name = v,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        LevelBar(level: lv.level, into: lv.into, need: lv.need),
        const SizedBox(height: 14),
        Row(children: [
          stat('بازی آنلاین', s.stat('games'), '🎮'),
          stat('برد', s.stat('wins'), '🏆'),
          stat('دورهمی', s.stat('party'), '🎉'),
        ]),
        Row(children: [
          stat('حدس درست', s.stat('guessed'), '🎯'),
          stat('نقاشی حدس‌خورده', s.stat('drawn'), '🖌️'),
          stat('بهترین امتیاز', s.stat('best'), '⭐'),
        ]),
        const SizedBox(height: 14),
        const SectionTitle('شکلک — با بالا رفتن سطح، شکلک‌های تازه باز می‌شن'),
        AvatarPicker(selected: s.avatar, level: lv.level, onPick: (a) => setState(() => s.avatar = a)),
      ]),
    );
  }
}

/* ------------------------------ settings ------------------------------ */

void showSettingsSheet(BuildContext context) => showGameSheet(context, (_) => const _SettingsSheet());

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final _host = TextEditingController(text: Settings.I.host);

  @override
  void dispose() {
    Settings.I.host = _host.text;
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    Widget toggle(String icon, String label, bool v, ValueChanged<bool> on) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: C.panel2, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              Switch(value: v, onChanged: (x) => setState(() => on(x))),
            ]),
          ),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('تنظیمات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        toggle('🔊', 'صدا', s.sound, (v) {
          s.sound = v;
          if (v) Sfx.play(Snd.select);
        }),
        toggle('📳', 'لرزش', s.haptics, (v) {
          s.haptics = v;
          if (v) Sfx.medium();
        }),
        const SizedBox(height: 8),
        const SectionTitle('سرور بازی آنلاین'),
        TextField(
          controller: _host,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: '192.168.1.10:8080'),
        ),
        const SizedBox(height: 6),
        const Text(
          'برای بازی آنلاین، آدرسی که برنامه‌ی سرور روی کامپیوتر نشون می‌ده رو اینجا بنویس. دورهمی به سرور نیازی نداره.',
          style: TextStyle(fontSize: 12, color: C.txtDim, height: 1.7),
        ),
        const SizedBox(height: 16),
        GhostButton('چطوری بازی کنم؟', icon: '📖', onTap: () => showHowToPlay(context)),
        const SizedBox(height: 14),
        const Text('نقاشی بکش — نسخه آزمایشی', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: C.txtDim)),
      ]),
    );
  }
}

/* ------------------------------ how to play ------------------------------ */

void showHowToPlay(BuildContext context) => showGameSheet(context, (_) => const _HowTo());

class _HowTo extends StatefulWidget {
  const _HowTo();
  @override
  State<_HowTo> createState() => _HowToState();
}

class _HowToState extends State<_HowTo> {
  final _pages = PageController();
  int _i = 0;

  static const cards = [
    ('🖌️', 'یکی می‌کشه', 'نقاش از بین سه کلمه یکی رو انتخاب می‌کنه و می‌کشه. نوشتن کلمه روی کاغذ ممنوعه!'),
    ('⌨️', 'بقیه حدس می‌زنن', 'حدست رو بنویس. هرچی زودتر، امتیاز بیشتر. اگه نزدیک باشی فقط خودت «نزدیکه!» رو می‌بینی.'),
    ('🔒', 'حل کردی؟ لو نده!', 'وقتی جواب رو زدی، پیام‌هات فقط به بقیه‌ی حل‌کننده‌ها می‌رسه.'),
    ('⚔️', 'بازی تیمی', 'فقط تیم نقاش حدس می‌زنه. اگه وقت تموم بشه، تیم مقابل ۱۰ ثانیه وقت داره امتیاز رو بدزده!'),
    ('🎉', 'دورهمی', 'با یک گوشی و بدون اینترنت: گوشی دست‌به‌دست می‌شه، نقاش می‌کشه یا ادا درمیاره و تیمش بلند حدس می‌زنه.'),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 380,
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) {
                Sfx.play(Snd.select);
                setState(() => _i = i);
              },
              children: [
                for (final (icon, title, body) in cards)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(icon, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: C.txtDim, height: 1.8)),
                    ]),
                  ),
              ],
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var j = 0; j < cards.length; j++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                width: j == _i ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(color: j == _i ? C.firuzeh : C.panel2, borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          const SizedBox(height: 16),
        ]),
      );
}

/* ------------------------------ online ------------------------------ */

enum OnlineChoice { create, join, quick }

/// Create a room, join by code, or quick-play. Returns the choice (and code).
Future<(OnlineChoice, String?)?> showOnlineSheet(BuildContext context) =>
    showGameSheet<(OnlineChoice, String?)>(context, (_) => const _OnlineSheet());

class _OnlineSheet extends StatefulWidget {
  const _OnlineSheet();
  @override
  State<_OnlineSheet> createState() => _OnlineSheetState();
}

class _OnlineSheetState extends State<_OnlineSheet> {
  final _code = TextEditingController();
  late final _host = TextEditingController(text: Settings.I.host);

  @override
  void dispose() {
    _code.dispose();
    _host.dispose();
    super.dispose();
  }

  void _pick(OnlineChoice c) {
    Settings.I.host = _host.text;
    if (_host.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اول آدرس سرور رو بنویس'), backgroundColor: C.anar));
      return;
    }
    if (c == OnlineChoice.join && _code.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کد اتاق ۵ حرفیه'), backgroundColor: C.anar));
      return;
    }
    Navigator.pop(context, (c, _code.text.trim().toUpperCase()));
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('بازی با دوستان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('هر کس با گوشی خودش، از هر جا که به سرور وصل باشه.', style: TextStyle(fontSize: 13, color: C.txtDim)),
          const SizedBox(height: 16),
          GameButton('ساخت اتاق خصوصی', icon: '🏠', onTap: () => _pick(OnlineChoice.create)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')), LengthLimitingTextInputFormatter(5)],
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 5),
                decoration: const InputDecoration(hintText: 'کد اتاق'),
                onSubmitted: (_) => _pick(OnlineChoice.join),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: GameButton.saffron('ورود', icon: '🔑', onTap: () => _pick(OnlineChoice.join)),
            ),
          ]),
          const SizedBox(height: 14),
          GhostButton('بازی سریع با بقیه (عمومی)', icon: '⚡', onTap: () => _pick(OnlineChoice.quick)),
          const SizedBox(height: 18),
          const SectionTitle('آدرس سرور'),
          TextField(
            controller: _host,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: '192.168.1.10:8080'),
          ),
          const SizedBox(height: 6),
          const Text('آدرسی که برنامه‌ی سرور روی کامپیوتر نشون می‌ده. همه‌ی گوشی‌ها باید روی همون وای‌فای باشن.',
              style: TextStyle(fontSize: 12, color: C.txtDim, height: 1.7)),
        ]),
      );
}
