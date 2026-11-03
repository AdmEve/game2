import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../net/game_client.dart';
import '../theme.dart';

/// Paints normalised strokes onto the cream paper.
class BoardPainter extends CustomPainter {
  BoardPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = C.kaghaz);
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final p = Paint()
        ..color = s.color
        ..strokeWidth = s.width * (size.width / 380)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (s.points.length == 1) {
        final o = Offset(s.points.first.dx * size.width, s.points.first.dy * size.height);
        canvas.drawCircle(o, p.strokeWidth / 2, p..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()
        ..moveTo(s.points.first.dx * size.width, s.points.first.dy * size.height);
      for (final o in s.points.skip(1)) {
        path.lineTo(o.dx * size.width, o.dy * size.height);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}

/// The paper. Interactive only when [enabled].
class DrawBoard extends StatefulWidget {
  const DrawBoard({
    super.key,
    required this.strokes,
    this.enabled = false,
    this.color = C.ink,
    this.width = 6,
    this.onStrokeDone,
  });

  final List<Stroke> strokes;
  final bool enabled;
  final Color color;
  final double width;
  final void Function(Stroke)? onStrokeDone;

  @override
  State<DrawBoard> createState() => _DrawBoardState();
}

class _DrawBoardState extends State<DrawBoard> {
  Stroke? _live;

  Offset _norm(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final all = [...widget.strokes, if (_live != null) _live!];

      final board = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(painter: BoardPainter(all), size: size),
      );

      if (!widget.enabled) return board;

      return Listener(
        onPointerDown: (e) => setState(() {
          _live = Stroke(
            color: widget.color,
            width: widget.width,
            points: [_norm(e.localPosition, size)],
          );
        }),
        onPointerMove: (e) {
          if (_live == null) return;
          setState(() => _live!.points.add(_norm(e.localPosition, size)));
        },
        onPointerUp: (_) {
          final s = _live;
          setState(() => _live = null);
          if (s != null) widget.onStrokeDone?.call(s);
        },
        child: board,
      );
    });
  }
}

/// Countdown ring; turns red in the last quarter.
class TimerRing extends StatelessWidget {
  const TimerRing({super.key, required this.seconds, required this.total, this.color = C.firuzeh});
  final int seconds;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    final urgent = seconds <= math.min(15, total * .25);
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: frac,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0x22FFFFFF),
              valueColor: AlwaysStoppedAnimation(urgent ? C.anar : color),
            ),
          ),
          Text(fa(seconds),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// The word as underscores, filling in as hints arrive.
class MaskedWord extends StatelessWidget {
  const MaskedWord({super.key, required this.mask});
  final List<String?> mask;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 5,
        children: mask.map((ch) {
          if (ch == ' ' || ch == '\u200c') return const SizedBox(width: 8);
          final revealed = ch != null;
          return Container(
            width: 19,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: revealed ? C.zaferan : C.txtDim, width: 2.5),
              ),
            ),
            child: Text(ch ?? '',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800, color: C.zaferan)),
          );
        }).toList(),
      ),
    );
  }
}

class ChatFeed extends StatelessWidget {
  const ChatFeed({super.key, required this.lines});
  final List<ChatLine> lines;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: lines.length,
      itemBuilder: (context, i) {
        final l = lines[lines.length - 1 - i];
        final (bg, fg) = switch (l.kind) {
          ChatKind.hit => (const Color(0x292AB5A6), C.firuzeh),
          ChatKind.near => (C.panel, C.zaferan),
          ChatKind.system => (C.panel, C.txtDim),
          ChatKind.normal => (C.panel, C.txt),
        };
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: l.kind == ChatKind.near ? C.zaferan : C.line,
              style: l.scope != null ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Row(children: [
            Text('${l.name} ',
                style: const TextStyle(
                    color: C.txtDim, fontSize: 13, fontWeight: FontWeight.w800)),
            Expanded(child: Text(l.text, style: TextStyle(color: fg, fontSize: 14))),
            if (l.scope != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: C.panel2, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  l.scope == 'private' ? 'فقط تو می‌بینی' : 'فقط حل‌کننده‌ها',
                  style: const TextStyle(
                      fontSize: 10.5, color: C.txtDim, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
        );
      },
    );
  }
}

/// Hold to talk. Voice only exists in private rooms; the drawer is muted in
/// team mode so they cannot say the word out loud.
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
        onTapDown: on
            ? (_) {
                setState(() => _live = true);
                widget.onHold?.call();
              }
            : null,
        onTapUp: on
            ? (_) {
                setState(() => _live = false);
                widget.onRelease?.call();
              }
            : null,
        onTapCancel: on
            ? () {
                setState(() => _live = false);
                widget.onRelease?.call();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _live ? C.anar : C.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _live ? C.anar : C.line),
          ),
          child: Text(
            widget.label ?? (on ? '🎙 نگه دار و حرف بزن' : '🔇 نقاش حق حرف زدن نداره'),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Team score bar shown above the board in team mode.
class TeamBar extends StatelessWidget {
  const TeamBar({super.key, required this.score, required this.turnTeam});
  final List<int> score;
  final int turnTeam;

  @override
  Widget build(BuildContext context) {
    const names = ['آبی', 'قرمز'];
    Widget side(int t, bool left) => Row(
          mainAxisAlignment: left ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                    color: t == 0 ? C.teamA : C.teamB, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(names[t], style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 7),
            Text(fa(score[t]),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: C.panel2,
      child: Row(children: [
        Expanded(child: side(0, true)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.line)),
          child: Text('نوبت تیم ${names[turnTeam]}',
              style: const TextStyle(fontSize: 11, color: C.txtDim, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: side(1, false)),
      ]),
    );
  }
}
