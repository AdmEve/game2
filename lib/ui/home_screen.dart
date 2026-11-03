import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../net/game_client.dart';
import '../theme.dart';
import 'game_screen.dart';

const kAvatars = ['🦊', '🐼', '🐯', '🦁', '🐸', '🐙', '🦉', '🐧', '🦄', '🐝', '🦖', '🐳'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  final _host = TextEditingController(text: '192.168.1.10:8080');
  String _avatar = '🦊';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _name.text = p.getString('name') ?? '';
        _avatar = p.getString('avatar') ?? '🦊';
        _host.text = p.getString('host') ?? _host.text;
      });
    });
  }

  Future<void> _go({String? code, bool public = false}) async {
    final name = _name.text.trim().isEmpty ? 'بازیکن' : _name.text.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('name', name);
    await p.setString('avatar', _avatar);
    await p.setString('host', _host.text.trim());

    final client = GameClient();
    setState(() => _busy = true);
    try {
      await client.connect(
        host: _host.text.trim(),
        name: name,
        avatar: _avatar,
        code: code,
        public: public,
      );
    } on ConnectFailed {
      client.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: C.anar,
          content: Text('به سرور وصل نشد. آدرس سرور رو چک کن و مطمئن شو گوشی و سرور روی یک وای‌فای‌ان.'),
        ));
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(client: client)),
    );
  }

  Future<void> _joinByCode() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: C.panel,
          title: const Text('کد اتاق', style: TextStyle(fontWeight: FontWeight.w800)),
          content: TextField(
            controller: c,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'مثلاً 7K4M2'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('بی‌خیال')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim().toUpperCase()),
                child: const Text('برو')),
          ],
        ),
      ),
    );
    if (code != null && code.isNotEmpty) _go(code: code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🎨', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontFamily: 'Vazirmatn', fontSize: 36, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(text: 'نقاشی '),
                    TextSpan(text: 'بکش', style: TextStyle(color: C.firuzeh)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 8),
            const Text('یکی می‌کشه، بقیه حدس می‌زنن.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.txtDim, fontSize: 15, height: 1.7)),
            const SizedBox(height: 22),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('اسمت چیه؟',
                    style: TextStyle(fontSize: 13, color: C.txtDim, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                TextField(
                    controller: _name,
                    maxLength: 14,
                    decoration: const InputDecoration(hintText: 'مثلاً پویا', counterText: '')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: kAvatars.map((a) {
                    final on = a == _avatar;
                    return GestureDetector(
                      onTap: () => setState(() => _avatar = a),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? const Color(0x292AB5A6) : C.panel2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: on ? C.firuzeh : Colors.transparent, width: 2),
                        ),
                        child: Text(a, style: const TextStyle(fontSize: 23)),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('آدرس سرور',
                    style: TextStyle(fontSize: 13, color: C.txtDim, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _host,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(hintText: '192.168.1.10:8080'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            PrimaryButton(_busy ? 'در حال وصل شدن…' : 'ساخت اتاق خصوصی',
                onTap: _busy ? null : () => _go()),
            const SizedBox(height: 8),
            GhostButton('با کد اتاق وارد شو', onTap: _busy ? null : _joinByCode),
            const SizedBox(height: 8),
            GhostButton('بازی سریع با بقیه', onTap: _busy ? null : () => _go(public: true)),
          ]),
        ),
      ),
    );
  }
}

/* ------------------------------ lobby ------------------------------ */

class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.client});
  final GameClient client;

  @override
  Widget build(BuildContext context) {
    final voice = client.voiceOn;
    final private = client.roomCode != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: voice ? C.line : const Color(0x66F2A93B)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(voice ? '🎙' : '💬', style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                voice
                    ? 'گفتگوی صوتی روشنه چون این اتاق خصوصیه.${client.isHost ? ' به‌عنوان میزبان می‌تونی هرکسی رو بی‌صدا یا اخراج کنی.' : ''}'
                    : private
                        ? 'اتاق خصوصیه: فقط کسایی که کد رو دارن میان تو.${client.isHost ? ' به‌عنوان میزبان می‌تونی هرکسی رو اخراج کنی.' : ''}'
                        : 'بازی عمومیه و فقط چت متنی داره.',
                style: const TextStyle(color: C.txtDim, fontSize: 13, height: 1.7),
              ),
            ),
          ]),
        ),
        if (client.roomCode != null) ...[
          const SizedBox(height: 14),
          Panel(
            child: Column(children: [
              const Text('کد اتاق رو برای دوستات بفرست',
                  style: TextStyle(color: C.txtDim, fontSize: 13)),
              const SizedBox(height: 6),
              Text(client.roomCode!,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w900, color: C.zaferan, letterSpacing: 6)),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        if (client.isHost)
          Row(children: [
            Expanded(child: _ModeChip('همه با هم', on: client.mode == 'ffa', onTap: () => client.setMode('ffa'))),
            const SizedBox(width: 8),
            Expanded(child: _ModeChip('تیمی', on: client.mode == 'team', onTap: () => client.setMode('team'))),
          ]),
        const SizedBox(height: 14),
        ...client.players.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: C.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.line),
              ),
              child: Row(children: [
                Text(p.avatar, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 11),
                Expanded(
                    child: Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                if (client.mode == 'team')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: p.team == 0 ? C.teamA : C.teamB,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(p.team == 0 ? 'آبی' : 'قرمز',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                if (kVoiceBuilt && p.hostMuted) const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('🔇', style: TextStyle(fontSize: 14)),
                ),
                if (p.id == client.myId)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text('تو', style: TextStyle(fontSize: 12, color: C.txtDim)),
                  )
                else if (client.isHost)
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 18, color: C.txtDim),
                    onPressed: () => _hostSheet(context, client, p),
                  ),
              ]),
            )),
        const SizedBox(height: 10),
        if (client.isHost)
          PrimaryButton('شروع بازی',
              onTap: client.players.length >= 2 ? client.start : null)
        else
          const Text('منتظر میزبان…',
              textAlign: TextAlign.center, style: TextStyle(color: C.txtDim)),
      ]),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(this.label, {required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? C.firuzeh : C.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? C.firuzeh : C.line),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: on ? const Color(0xFF06231F) : C.txt)),
        ),
      );
}

void _hostSheet(BuildContext context, GameClient client, Player p) {
  showModalBottomSheet(
    context: context,
    backgroundColor: C.panel,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (kVoiceBuilt) _SheetAction(
              icon: p.hostMuted ? '🔊' : '🚫',
              label: p.hostMuted ? 'اجازه حرف زدن بده' : 'برای همه بی‌صدا کن',
              note: 'میزبان: کسی صداش رو نمی‌شنوه',
              onTap: () {
                client.hostMute(p.id);
                Navigator.pop(ctx);
              },
            ),
            _SheetAction(
              icon: '👋',
              label: 'اخراج از اتاق',
              note: 'از اتاق بیرونش می‌کنه',
              danger: true,
              onTap: () {
                client.hostKick(p.id);
                Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      ),
    ),
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction(
      {required this.icon, required this.label, required this.note, required this.onTap, this.danger = false});
  final String icon, label, note;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: C.panel2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.line)),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: danger ? C.anar : C.txt)),
              Text(note, style: const TextStyle(fontSize: 12, color: C.txtDim)),
            ]),
          ]),
        ),
      );
}
