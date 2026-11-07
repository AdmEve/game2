import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../core/sfx.dart';
import '../../net/game_client.dart';
import '../../theme.dart';
import '../fx.dart';
import '../share.dart';
import '../widgets.dart';

class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.client});
  final GameClient client;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final private = c.roomCode != null;
    final team = c.mode == 'team';
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        if (private)
          Appear(
            child: Panel(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(children: [
                const Text('کد اتاق رو برای دوستات بفرست', style: TextStyle(color: C.txtDim, fontSize: 13)),
                const SizedBox(height: 4),
                Semantics(
                  label: 'کد اتاق ${c.roomCode}',
                  child: Text(c.roomCode!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w900, color: C.zaferan, letterSpacing: 8,
                          shadows: [Shadow(color: Color(0x66F2A93B), blurRadius: 18)])),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: GameButton.saffron('بفرست', icon: '📤', onTap: () => shareInvite(c.roomCode!))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhostButton('کپی', icon: '📋', onTap: () {
                      Clipboard.setData(ClipboardData(text: c.roomCode!));
                      showToast(context, 'کد کپی شد', icon: '📋');
                    }),
                  ),
                ]),
              ]),
            ),
          )
        else
          const Appear(
            child: Panel(
              child: Row(children: [
                Text('⚡', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Expanded(child: Text('بازی عمومی: فقط چت متنی، همه با هم.', style: TextStyle(color: C.txtDim, height: 1.6))),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Text('بازیکن‌ها (${fa(c.players.length)})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (team) const Text('تیم‌ها یکی در میون چیده می‌شن', style: TextStyle(fontSize: 11.5, color: C.txtDim)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 12, children: [
          for (var i = 0; i < c.players.length; i++)
            Appear(
              key: ValueKey(c.players[i].id),
              delay: stagger(i, 40),
              scale: true,
              child: _PlayerTile(client: c, p: c.players[i]),
            ),
        ]),
        const SizedBox(height: 20),
        if (c.isHost) ...[
          const SectionTitle('حالت بازی'),
          Row(children: [
            Expanded(child: ChoiceChipX('🎨 همه با هم', on: !team, onTap: () => c.setMode('ffa'))),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChipX('⚔️ تیمی', on: team, onTap: private ? () => c.setMode('team') : null),
            ),
          ]),
          const SizedBox(height: 14),
          const SectionTitle('تعداد دور (هر نفر در هر دور یک بار می‌کشه)'),
          Row(children: [
            for (final r in [1, 2, 3, 4, 5])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChipX(fa(r), on: c.rounds == r, onTap: () => c.setRounds(r), color: C.zaferan),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          const SectionTitle('زمان هر نوبت (ثانیه)'),
          Row(children: [
            for (final s in <int?>[null, 45, 60, 80, 100, 120])
              Expanded(
                flex: s == null ? 2 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: ChoiceChipX(
                    s == null ? 'خودکار' : fa(s),
                    on: s == null ? c.turnLenAuto : (!c.turnLenAuto && c.turnLen == s),
                    onTap: () => c.setTurnLen(s),
                    color: C.zaferan,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          GameButton(
            c.players.length >= 2 ? 'شروع بازی' : 'حداقل یک نفر دیگه لازمه',
            icon: '▶️',
            big: true,
            sound: Snd.turn,
            onTap: c.players.length >= 2 ? c.start : null,
          ),
        ] else ...[
          Panel(
            child: Column(children: [
              Text(team ? '⚔️ بازی تیمی' : '🎨 همه با هم', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${fa(c.rounds)} دور · ${c.turnLenAuto ? 'زمان خودکار' : '${fa(c.turnLen)} ثانیه برای هر نوبت'}',
                  style: const TextStyle(color: C.txtDim)),
              const SizedBox(height: 12),
              const _WaitingDots(text: 'منتظر میزبان'),
            ]),
          ),
        ],
        if (kVoiceBuilt && c.voiceOn) ...[
          const SizedBox(height: 12),
          const Text('🎙 گفتگوی صوتی روشنه', textAlign: TextAlign.center, style: TextStyle(color: C.txtDim)),
        ],
      ],
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.client, required this.p});
  final GameClient client;
  final Player p;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final me = p.id == c.myId;
    final host = p.id == c.hostId;
    final tile = SizedBox(
      width: 76,
      child: Column(children: [
        AvatarBubble(
          p.avatar,
          size: 58,
          dim: p.away,
          ring: c.mode == 'team' ? C.team(p.team) : (me ? C.firuzeh : null),
          badge: p.away ? '📶' : (host ? '👑' : null),
        ),
        const SizedBox(height: 4),
        Text(me ? '${p.name} (تو)' : p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: me ? C.firuzeh : C.txt)),
        if (p.away) const Text('در حال اتصال…', style: TextStyle(fontSize: 10, color: C.txtDim)),
      ]),
    );
    if (!c.isHost || me || c.roomCode == null) return tile;
    return Pressable(onTap: () => _hostSheet(context, c, p), child: tile);
  }
}

void _hostSheet(BuildContext context, GameClient client, Player p) {
  showModalBottomSheet(
    context: context,
    backgroundColor: C.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AvatarBubble(p.avatar, size: 56),
            const SizedBox(height: 6),
            Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (kVoiceBuilt) ...[
              GhostButton(p.hostMuted ? 'اجازه حرف زدن بده' : 'برای همه بی‌صدا کن', icon: p.hostMuted ? '🔊' : '🚫', onTap: () {
                client.hostMute(p.id);
                Navigator.pop(ctx);
              }),
              const SizedBox(height: 8),
            ],
            GameButton.danger('از اتاق بیرونش کن', icon: '👋', onTap: () {
              client.hostKick(p.id);
              Navigator.pop(ctx);
            }),
          ]),
        ),
      ),
    ),
  );
}

class _WaitingDots extends StatefulWidget {
  const _WaitingDots({required this.text});
  final String text;
  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Text('${widget.text}${'.' * (1 + (_c.value * 3).floor())}',
            style: const TextStyle(color: C.firuzeh, fontWeight: FontWeight.w800)),
      );
}
