import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/sfx.dart';
import '../net/game_client.dart';
import '../theme.dart';
import 'fx.dart';

/// Countdown ring; pulses red in the last stretch.
class TimerRing extends StatelessWidget {
  const TimerRing({super.key, required this.seconds, required this.total, this.color = C.firuzeh, this.size = 50});
  final int seconds;
  final int total;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    final urgent = seconds > 0 && seconds <= math.min(10, total * .25);
    return Semantics(
      label: '${fa(seconds)} ثانیه مونده',
      excludeSemantics: true,
      child: Pulse(
        active: urgent,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: size,
              height: size,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: frac),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0x22FFFFFF),
                  valueColor: AlwaysStoppedAnimation(urgent ? C.anar : color),
                ),
              ),
            ),
            Text(fa(seconds),
                style: TextStyle(fontSize: size * .34, fontWeight: FontWeight.w900, color: urgent ? C.anar : C.txt)),
          ]),
        ),
      ),
    );
  }
}

/// The word as blanks, each letter popping in as hints arrive.
class MaskedWord extends StatelessWidget {
  const MaskedWord({super.key, required this.mask});
  final List<String?> mask;

  @override
  Widget build(BuildContext context) {
    final letters = mask.where((c) => c != ' ' && c != '‌').length;
    return Semantics(
      label: 'کلمه $letters حرفی',
      excludeSemantics: true,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 5,
          runSpacing: 4,
          children: [
            for (final ch in mask)
              if (ch == ' ' || ch == '‌')
                const SizedBox(width: 10)
              else
                Container(
                  width: 20,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: ch != null ? C.zaferan : C.txtDim, width: 2.6)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: c),
                    child: Text(ch ?? '',
                        key: ValueKey(ch),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.zaferan)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class ChatFeed extends StatelessWidget {
  const ChatFeed({super.key, required this.lines, this.compact = false});
  final List<ChatLine> lines;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Center(
        child: Text(compact ? 'حدس‌ها اینجا میان' : 'حدس‌ها اینجا نشون داده می‌شن',
            style: const TextStyle(color: C.txtDim, fontSize: 12.5)),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final l = lines[lines.length - 1 - i];
        final (bg, fg) = switch (l.kind) {
          ChatKind.hit => (const Color(0x332AB5A6), C.firuzeh),
          ChatKind.near => (const Color(0x22F2A93B), C.zaferan),
          ChatKind.system => (C.panel, C.txtDim),
          ChatKind.normal => (C.panel, C.txt),
        };
        final row = Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 5 : 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: l.kind == ChatKind.near ? C.zaferan : (l.kind == ChatKind.hit ? C.firuzeh : C.line)),
          ),
          child: Row(children: [
            if (l.kind == ChatKind.hit) const Padding(padding: EdgeInsetsDirectional.only(end: 6), child: Text('🎉', style: TextStyle(fontSize: 13))),
            if (l.kind == ChatKind.near) const Padding(padding: EdgeInsetsDirectional.only(end: 6), child: Text('🔥', style: TextStyle(fontSize: 13))),
            Text('${l.name} ', style: const TextStyle(color: C.txtDim, fontSize: 13, fontWeight: FontWeight.w800)),
            Expanded(
              child: Text(l.kind == ChatKind.near ? '${l.text} — نزدیکه!' : l.text,
                  style: TextStyle(color: fg, fontSize: 14, fontWeight: l.kind == ChatKind.normal ? FontWeight.w500 : FontWeight.w800)),
            ),
            if (l.scope != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.panel2, borderRadius: BorderRadius.circular(20)),
                child: Text(l.scope == 'private' ? 'فقط تو می‌بینی' : '🔒 فقط حل‌کننده‌ها',
                    style: const TextStyle(fontSize: 10.5, color: C.txtDim, fontWeight: FontWeight.w700)),
              ),
          ]),
        );
        // the newest line slides in
        return i == 0 ? Appear(key: ValueKey(lines.length), from: const Offset(0, .5), child: row) : row;
      },
    );
  }
}

/// Round avatar with an optional coloured ring and badge.
class AvatarBubble extends StatelessWidget {
  const AvatarBubble(this.emoji, {super.key, this.size = 46, this.ring, this.badge, this.dim = false});
  final String emoji;
  final double size;
  final Color? ring;
  final String? badge;
  final bool dim;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: dim ? .4 : 1,
        child: SizedBox(
          width: size + 6,
          height: size + 6,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.panel2, C.panel]),
                border: Border.all(color: ring ?? C.line, width: ring == null ? 1 : 2.6),
              ),
              child: Text(emoji, style: TextStyle(fontSize: size * .52)),
            ),
            if (badge != null)
              Positioned(
                bottom: -2,
                left: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(color: C.lajvard, shape: BoxShape.circle),
                  child: Text(badge!, style: TextStyle(fontSize: size * .28)),
                ),
              ),
          ]),
        ),
      );
}

/// Everyone in the room, during a turn: drawer ✏️, solved 🔒, away dimmed.
class PlayerStrip extends StatelessWidget {
  const PlayerStrip({super.key, required this.client});
  final GameClient client;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final team = c.mode == 'team';
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        children: [
          for (final p in c.players)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 58,
                child: Column(children: [
                  AnimatedScale(
                    scale: p.solved ? 1.08 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: AvatarBubble(
                      p.avatar,
                      size: 40,
                      dim: p.away,
                      ring: p.id == c.drawerId
                          ? C.zaferan
                          : p.solved
                              ? C.firuzeh
                              : (team ? C.team(p.team) : null),
                      badge: p.away ? '📶' : p.id == c.drawerId ? '✏️' : (p.solved ? '🔒' : null),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(p.id == c.myId ? 'تو' : p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: p.id == c.myId ? C.firuzeh : C.txtDim, fontWeight: FontWeight.w700)),
                  if (!team)
                    Text(fa(p.score), style: const TextStyle(fontSize: 10.5, color: C.zaferan, fontWeight: FontWeight.w900, height: 1.1)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Team score bar shown above the board in team mode.
class TeamBar extends StatelessWidget {
  const TeamBar({super.key, required this.score, required this.turnTeam, this.names = kTeamNames});
  final List<int> score;
  final int turnTeam;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    Widget side(int t) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: C.team(t).withValues(alpha: t == turnTeam ? .28 : .1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.team(t).withValues(alpha: t == turnTeam ? .9 : .25), width: t == turnTeam ? 2 : 1),
            ),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: C.team(t), shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(t == turnTeam ? '${names[t]} ✏️' : names[t],
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              CountUp(score[t], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: Row(children: [side(0), const SizedBox(width: 8), side(1)]),
    );
  }
}

/// Colours, brush sizes, eraser, undo and clear for the drawer.
class ToolTray extends StatefulWidget {
  const ToolTray({
    super.key,
    required this.color,
    required this.width,
    required this.eraser,
    required this.onColor,
    required this.onWidth,
    required this.onEraser,
    required this.onUndo,
    required this.onClear,
    this.trailing,
  });
  final Color color;
  final double width;
  final bool eraser;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onWidth;
  final ValueChanged<bool> onEraser;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final Widget? trailing;

  @override
  State<ToolTray> createState() => _ToolTrayState();
}

class _ToolTrayState extends State<ToolTray> {
  bool _confirmClear = false;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Widget _tool(String icon, String label, {required bool on, required VoidCallback onTap, Color? tint}) => Semantics(
        label: label,
        button: true,
        selected: on,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 46,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? (tint ?? C.firuzeh) : C.panel2,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: on ? (tint ?? C.firuzeh) : C.line),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 19)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final col in kPalette)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Semantics(
                  label: 'رنگ',
                  button: true,
                  selected: !widget.eraser && col == widget.color,
                  excludeSemantics: true,
                  child: Pressable(
                    sound: Snd.select,
                    onTap: () {
                      widget.onColor(col);
                      widget.onEraser(false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: !widget.eraser && col == widget.color ? C.txt : const Color(0x33FFFFFF),
                            width: !widget.eraser && col == widget.color ? 3 : 1),
                        boxShadow: !widget.eraser && col == widget.color
                            ? [BoxShadow(color: col.withValues(alpha: .6), blurRadius: 10)]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        for (final s in kBrushSizes)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 5),
            child: Semantics(
              label: 'اندازه قلم',
              button: true,
              selected: s == widget.width,
              excludeSemantics: true,
              child: Pressable(
                sound: Snd.select,
                onTap: () => widget.onWidth(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s == widget.width ? C.zaferan : C.panel2,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: s == widget.width ? C.zaferan : C.line),
                  ),
                  child: Container(
                    width: (s * .75).clamp(4, 20),
                    height: (s * .75).clamp(4, 20),
                    decoration: BoxDecoration(
                        color: s == widget.width ? C.onZaferan : (widget.eraser ? C.kaghaz : widget.color == C.ink ? C.txt : widget.color),
                        shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        _tool('🧽', 'پاک‌کن', on: widget.eraser, tint: C.zaferan, onTap: () => widget.onEraser(!widget.eraser)),
        const SizedBox(width: 5),
        _tool('↩️', 'برگرد', on: false, onTap: widget.onUndo),
        const SizedBox(width: 5),
        _tool(_confirmClear ? '❓' : '🗑️', _confirmClear ? 'دوباره بزن تا پاک بشه' : 'پاک کردن همه', on: _confirmClear, tint: C.anar, onTap: () {
          if (_confirmClear) {
            _t?.cancel();
            setState(() => _confirmClear = false);
            Sfx.medium();
            widget.onClear();
          } else {
            setState(() => _confirmClear = true);
            _t = Timer(const Duration(seconds: 2), () {
              if (mounted) setState(() => _confirmClear = false);
            });
          }
        }),
      ]),
      if (widget.trailing != null) ...[const SizedBox(height: 8), widget.trailing!],
    ]);
  }
}

/// Hold to talk. Voice only exists in private rooms; the drawer is muted in
/// team mode so they cannot say the word out loud. Hidden until kVoiceBuilt.
class PushToTalk extends StatefulWidget {
  const PushToTalk({super.key, required this.enabled, this.label, this.onHold, this.onRelease});
  final bool enabled;
  final String? label;
  final VoidCallback? onHold;
  final VoidCallback? onRelease;

  @override
  State<PushToTalk> createState() => _PushToTalkState();
}

class _PushToTalkState extends State<PushToTalk> {
  bool _live = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return Opacity(
      opacity: on ? 1 : .4,
      child: GestureDetector(
        onTapDown: on ? (_) { setState(() => _live = true); widget.onHold?.call(); } : null,
        onTapUp: on ? (_) { setState(() => _live = false); widget.onRelease?.call(); } : null,
        onTapCancel: on ? () { setState(() => _live = false); widget.onRelease?.call(); } : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _live ? C.anar : C.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _live ? C.anar : C.line),
          ),
          child: Text(widget.label ?? (on ? '🎙 نگه دار و حرف بزن' : '🔇 نقاش حق حرف زدن نداره'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Small heading used on sheets and screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: const TextStyle(fontSize: 13, color: C.txtDim, fontWeight: FontWeight.w800)),
      );
}

/// Level badge + XP bar.
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.level, required this.into, required this.need, this.compact = false});
  final int level, into, need;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 2 : 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.zaferan, C.gold]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('سطح ${fa(level)}',
              style: TextStyle(fontSize: compact ? 10.5 : 12.5, fontWeight: FontWeight.w900, color: C.onZaferan)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: need == 0 ? 0 : into / need),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: compact ? 6 : 9,
                backgroundColor: C.panel2,
                valueColor: const AlwaysStoppedAnimation(C.zaferan),
              ),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Text('${fa(into)}/${fa(need)}', style: const TextStyle(fontSize: 11.5, color: C.txtDim, fontWeight: FontWeight.w700)),
        ],
      ]);
}

/// The guess/chat input. Keeps the keyboard up between guesses (people type
/// several in a row) and clears itself after each send.
class GuessBar extends StatefulWidget {
  const GuessBar({super.key, required this.enabled, required this.hint, required this.onSend});
  final bool enabled;
  final String hint;
  final ValueChanged<String> onSend;

  @override
  State<GuessBar> createState() => _GuessBarState();
}

class _GuessBarState extends State<GuessBar> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _text.text.trim();
    if (t.isEmpty || !widget.enabled) return;
    widget.onSend(t);
    Sfx.play(Snd.chat);
    _text.clear();
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(color: C.panel, border: Border(top: BorderSide(color: C.line))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              enabled: widget.enabled,
              maxLength: 60,
              textInputAction: TextInputAction.send,
              onEditingComplete: () {}, // don't drop focus (and the keyboard) on send
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(hintText: widget.hint, counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'بفرست',
            excludeSemantics: true,
            child: Pressable(
              onTap: widget.enabled ? _submit : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 54,
                height: 52,
                decoration: BoxDecoration(color: widget.enabled ? C.firuzeh : C.panel2, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.send_rounded, color: C.onFiruzeh, size: 22, textDirection: TextDirection.rtl),
              ),
            ),
          ),
        ]),
      );
}

