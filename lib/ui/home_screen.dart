import 'package:flutter/material.dart';

import '../core/progress.dart';
import '../core/settings.dart';
import '../core/sfx.dart';
import '../net/game_client.dart';
import '../theme.dart';
import 'fx.dart';
import 'online/game_screen.dart';
import 'party/party_setup.dart';
import 'sheets.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Settings.I.addListener(_refresh);
  }

  @override
  void dispose() {
    Settings.I.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _online() async {
    final pick = await showOnlineSheet(context);
    if (pick == null || !mounted) return;
    final s = Settings.I;
    final client = GameClient();
    setState(() => _busy = true);
    try {
      await client.connect(
        host: s.host,
        name: s.name.isEmpty ? 'بازیکن' : s.name,
        avatar: s.avatar,
        code: pick.$1 == OnlineChoice.join ? pick.$2 : null,
        public: pick.$1 == OnlineChoice.quick,
      );
    } on ConnectFailed catch (e) {
      client.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: C.anar,
          content: Text(switch (e.why) {
            'no_room' => 'اتاقی با این کد پیدا نشد. کد رو دوباره چک کن.',
            'in_progress' => 'بازی این اتاق شروع شده. صبر کن تموم بشه.',
            _ => 'به سرور وصل نشد. آدرس سرور رو چک کن و مطمئن شو گوشی و سرور روی یک وای‌فای‌ان.',
          }),
        ));
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnlineGameScreen(client: client)));
    if (mounted) setState(() {});
  }

  void _party() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartySetupScreen()));

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    final lv = Progress.levelOf(s.xp);
    return Scaffold(
      body: DoodleBackground(
        child: SafeArea(
          child: Stack(children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(children: [
                  Expanded(
                    child: Semantics(
                      label: 'پروفایل',
                      button: true,
                      child: Pressable(
                        onTap: () => showProfileSheet(context),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                          decoration: BoxDecoration(
                            color: C.panel.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: C.line),
                          ),
                          child: Row(children: [
                            AvatarBubble(s.avatar, size: 40, ring: C.zaferan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(s.name.isEmpty ? 'بازیکن' : s.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 3),
                                LevelBar(level: lv.level, into: lv.into, need: lv.need, compact: true),
                              ]),
                            ),
                            const SizedBox(width: 10),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    label: 'تنظیمات',
                    button: true,
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: () => showSettingsSheet(context),
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: C.panel.withValues(alpha: .85), shape: BoxShape.circle, border: Border.all(color: C.line)),
                        child: const Text('⚙️', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 34),
                const Appear(scale: true, child: Center(child: Logo(size: 46))),
                const SizedBox(height: 12),
                const Appear(
                  delay: Duration(milliseconds: 120),
                  child: Text('یکی می‌کشه، بقیه حدس می‌زنن.',
                      textAlign: TextAlign.center, style: TextStyle(color: C.txtDim, fontSize: 15.5)),
                ),
                const SizedBox(height: 34),
                Appear(
                  delay: stagger(2),
                  child: _ModeCard(
                    icon: '🎉',
                    title: 'دورهمی',
                    subtitle: 'با یک گوشی و بدون اینترنت\nنقاشی یا پانتومیم، تیمی',
                    colors: const [Color(0xFFF7B955), C.zaferan, C.zaferanDark],
                    fg: C.onZaferan,
                    badge: 'آفلاین',
                    onTap: _party,
                  ),
                ),
                const SizedBox(height: 14),
                Appear(
                  delay: stagger(3),
                  child: _ModeCard(
                    icon: '🎨',
                    title: 'بازی با دوستان',
                    subtitle: 'هر کس با گوشی خودش\nاتاق بساز یا با کد وارد شو',
                    colors: const [Color(0xFF3FD0C0), C.firuzeh, C.firuzehDark],
                    fg: C.onFiruzeh,
                    badge: 'آنلاین',
                    onTap: _busy ? null : _online,
                  ),
                ),
                const SizedBox(height: 22),
                Appear(
                  delay: stagger(4),
                  child: Center(
                    child: Pressable(
                      onTap: () => showHowToPlay(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('📖  چطوری بازی کنم؟',
                            style: TextStyle(color: C.txtDim, fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xAA0B1730),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: C.firuzeh),
                      SizedBox(height: 14),
                      Text('در حال وصل شدن…', style: TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.fg,
    required this.onTap,
    this.badge,
  });
  final String icon, title, subtitle;
  final List<Color> colors;
  final Color fg;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: title,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          sound: Snd.select,
          scale: .97,
          child: Container(
            height: 132,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors.sublist(0, 2)),
              boxShadow: [
                BoxShadow(color: colors[2], offset: const Offset(0, 6)),
                const BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 14)),
              ],
            ),
            child: Stack(children: [
              PositionedDirectional(
                end: -10,
                bottom: -18,
                child: Opacity(opacity: .22, child: Text(icon, style: const TextStyle(fontSize: 120))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Row(children: [
                  Text(icon, style: const TextStyle(fontSize: 46)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Row(children: [
                        Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: fg)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: fg.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
                            child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 13.5, height: 1.6, fontWeight: FontWeight.w600, color: fg.withValues(alpha: .85))),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}
