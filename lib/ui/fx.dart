import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/* ------------------------------ entrances ------------------------------ */

/// Fades and slides its child in after [delay]. Everything that appears on a
/// screen uses this, staggered, so nothing just pops into existence.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.delay = Duration.zero, this.from = const Offset(0, .12), this.scale = false});
  final Widget child;
  final Duration delay;
  final Offset from;
  final bool scale;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: widget.scale ? Curves.easeOutBack : Curves.easeOutCubic);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      child: widget.scale
          ? ScaleTransition(scale: Tween(begin: .6, end: 1.0).animate(curve), child: widget.child)
          : SlideTransition(position: Tween(begin: widget.from, end: Offset.zero).animate(curve), child: widget.child),
    );
  }
}

Duration stagger(int i, [int ms = 70]) => Duration(milliseconds: 60 + i * ms);

/* ------------------------------ count-up ------------------------------ */

/// An integer that rolls up to its value, in Persian digits.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.from = 0, this.style, this.prefix = '', this.duration = const Duration(milliseconds: 900)});
  final int value;
  final int from;
  final TextStyle? style;
  final String prefix;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: from.toDouble(), end: value.toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('$prefix${fa(v.round())}', style: style),
      );
}

/* ------------------------------ confetti ------------------------------ */

class _Bit {
  _Bit(math.Random r, Size s, Offset origin)
      : pos = origin,
        vel = Offset((r.nextDouble() - .5) * s.width * 1.6, -s.height * (.6 + r.nextDouble() * .7)),
        spin = (r.nextDouble() - .5) * 14,
        size = 6 + r.nextDouble() * 7,
        color = [C.firuzeh, C.zaferan, C.anar, C.teamA, C.gold, C.kaghaz][r.nextInt(6)],
        round = r.nextBool();
  Offset pos;
  Offset vel;
  double angle = 0;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

/// A burst of confetti over the whole screen. Put it in a Stack; it plays
/// once each time [trigger] changes.
class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.trigger, this.count = 90, this.origin = const Alignment(0, .2)});
  final Object trigger;
  final int count;
  final Alignment origin;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..addListener(_step);
  final _bits = <_Bit>[];
  Size _size = Size.zero;
  Duration _last = Duration.zero;

  @override
  void didUpdateWidget(covariant Confetti old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _fire();
  }

  void _fire() {
    if (!mounted || _size == Size.zero) return;
    final r = math.Random();
    final o = widget.origin.alongSize(_size);
    _bits
      ..clear()
      ..addAll(List.generate(widget.count, (_) => _Bit(r, _size, o)));
    _last = Duration.zero;
    _c.forward(from: 0);
  }

  void _step() {
    final now = _c.lastElapsedDuration ?? Duration.zero;
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    for (final b in _bits) {
      b.vel = Offset(b.vel.dx * .985, b.vel.dy + _size.height * 1.5 * dt);
      b.pos += b.vel * dt;
      b.angle += b.spin * dt;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(builder: (_, box) {
          _size = Size(box.maxWidth, box.maxHeight);
          return CustomPaint(size: _size, painter: _ConfettiPainter(_bits, 1 - _c.value));
        }),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.fade);
  final List<_Bit> bits;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0) return;
    final p = Paint();
    for (final b in bits) {
      p.color = b.color.withValues(alpha: (fade * 1.6).clamp(0, 1));
      canvas.save();
      canvas.translate(b.pos.dx, b.pos.dy);
      canvas.rotate(b.angle);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2.4, p);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .45), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

/* ------------------------------ doodles ------------------------------ */

/// Slowly drifting hand-drawn shapes behind menus: the game's wallpaper.
class DoodleBackground extends StatefulWidget {
  const DoodleBackground({super.key, this.child, this.opacity = .09});
  final Widget? child;
  final double opacity;

  @override
  State<DoodleBackground> createState() => _DoodleBackgroundState();
}

class _DoodleBackgroundState extends State<DoodleBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DoodleBackground old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Hidden doodles (during a turn) cost nothing: no ticker, no repaint.
  void _sync() {
    if (widget.opacity <= 0) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.6),
                radius: 1.3,
                colors: [Color(0xFF1C3766), C.lajvard, C.lajvardDeep],
                stops: [0, .55, 1],
              ),
            ),
            child: widget.opacity <= 0
                ? null
                : RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, __) => CustomPaint(painter: _DoodlePainter(_c.value, widget.opacity)),
                    ),
                  ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ]);
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.t, this.opacity);
  final double t;
  final double opacity;

  static final _seeds = List.generate(16, (i) => math.Random(i * 7 + 3));
  static final _items = [
    for (final r in _seeds)
      (
        x: r.nextDouble(),
        y: r.nextDouble(),
        kind: r.nextInt(5),
        s: 18 + r.nextDouble() * 30,
        speed: .3 + r.nextDouble() * .7,
        phase: r.nextDouble() * math.pi * 2,
        color: [C.firuzeh, C.zaferan, C.anar, C.kaghaz][r.nextInt(4)],
      ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final it in _items) {
      final a = t * math.pi * 2 * it.speed + it.phase;
      final c = Offset(
        (it.x * size.width + math.sin(a) * 18) % size.width,
        (it.y * size.height - t * size.height * .25 * it.speed) % size.height,
      );
      p.color = it.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(math.sin(a * .7) * .5);
      final s = it.s;
      switch (it.kind) {
        case 0: // star
          final path = Path();
          for (var i = 0; i < 10; i++) {
            final r = i.isEven ? s * .5 : s * .22;
            final ang = -math.pi / 2 + i * math.pi / 5;
            final pt = Offset(math.cos(ang) * r, math.sin(ang) * r);
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path..close(), p);
        case 1: // squiggle
          final path = Path()..moveTo(-s * .6, 0);
          for (var i = 0; i < 4; i++) {
            path.relativeQuadraticBezierTo(s * .15, i.isEven ? -s * .3 : s * .3, s * .3, 0);
          }
          canvas.drawPath(path, p);
        case 2: // circle
          canvas.drawCircle(Offset.zero, s * .32, p);
        case 3: // pencil
          canvas.drawLine(Offset(-s * .4, s * .4), Offset(s * .3, -s * .3), p);
          canvas.drawLine(Offset(s * .3, -s * .3), Offset(s * .45, -s * .45), p..strokeWidth = 5);
          p.strokeWidth = 3;
        default: // heart-ish swirl
          canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: s * .35), 0, math.pi * 1.5, false, p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) => old.t != t;
}

/* ------------------------------ logo ------------------------------ */

/// «نقاشی بکش» with a saffron brush swash under «بکش».
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'نقاشی بکش',
        excludeSemantics: true,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          Positioned(
            bottom: -size * .08,
            left: 0,
            right: size * 1.2,
            child: CustomPaint(size: Size(size * 2.6, size * .5), painter: _SwashPainter()),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text('نقاشی ', style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, height: 1.3)),
            Text('بکش',
                style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    color: C.firuzeh,
                    height: 1.3,
                    shadows: const [Shadow(color: Color(0x662AB5A6), blurRadius: 18)])),
            SizedBox(width: size * .25),
            Transform.rotate(angle: -.2, child: Text('🖌️', style: TextStyle(fontSize: size * .8))),
          ]),
        ]),
      );
}

class _SwashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.zaferan.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * .32;
    final path = Path()
      ..moveTo(size.width * .05, size.height * .65)
      ..quadraticBezierTo(size.width * .5, size.height * .1, size.width * .95, size.height * .45);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* ------------------------------ toasts ------------------------------ */

/// A banner that drops in from the top for a moment ("سارا حدس زد!").
void showToast(BuildContext context, String text, {Color color = C.firuzeh, Color fg = C.onFiruzeh, String? icon}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(text: text, color: color, fg: fg, icon: icon, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.text, required this.color, required this.fg, this.icon, required this.onDone});
  final String text;
  final Color color, fg;
  final String? icon;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = _c.value;
        final inOut = v < .15 ? Curves.easeOutBack.transform(v / .15) : v > .85 ? 1 - Curves.easeIn.transform((v - .85) / .15) : 1.0;
        return Positioned(
          top: MediaQuery.paddingOf(context).top + 8 + (inOut - 1) * 60,
          left: 24,
          right: 24,
          child: IgnorePointer(
            child: Opacity(
              opacity: inOut.clamp(0, 1).toDouble(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (widget.icon != null) ...[Text(widget.icon!, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8)],
                      Flexible(
                        child: Text(widget.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Vazirmatn', color: widget.fg, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ------------------------------ big floating score ------------------------------ */

/// "+۲۷۸" that pops in the middle of the screen and floats away.
class ScorePop extends StatefulWidget {
  const ScorePop({super.key, required this.points, required this.trigger});
  final int points;
  final Object trigger;

  @override
  State<ScorePop> createState() => _ScorePopState();
}

class _ScorePopState extends State<ScorePop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant ScorePop old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final v = _c.value;
            if (v == 0 || v == 1) return const SizedBox.shrink();
            final s = Curves.elasticOut.transform((v * 2.2).clamp(0, 1));
            final fade = v > .7 ? 1 - (v - .7) / .3 : 1.0;
            return Align(
              alignment: Alignment(0, -.1 - v * .3),
              child: Opacity(
                opacity: fade,
                child: Transform.scale(
                  scale: .4 + s * .8,
                  child: Text('+${fa(widget.points)}',
                      style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: C.gold,
                          shadows: [Shadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 4))])),
                ),
              ),
            );
          },
        ),
      );
}

/// Gently pulses its child (used on the timer in the last seconds).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, required this.active});
  final Widget child;
  final bool active;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void didUpdateWidget(covariant Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.active && _c.isAnimating) _c.animateTo(0, duration: const Duration(milliseconds: 150));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: Tween(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
}
