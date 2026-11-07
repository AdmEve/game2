import 'package:flutter/material.dart';

import 'core/sfx.dart';

/// Persian ceramic palette: lâjvard chrome, firuzeh accent, saffron highlight,
/// cream drawing surface so the canvas reads as ink on paper.
class C {
  static const lajvard = Color(0xFF12233F);
  static const lajvardDeep = Color(0xFF0B1730);
  static const panel = Color(0xFF172E52);
  static const panel2 = Color(0xFF1F3D6E);
  static const firuzeh = Color(0xFF2AB5A6);
  static const firuzehDark = Color(0xFF1B8378);
  static const zaferan = Color(0xFFF2A93B);
  static const zaferanDark = Color(0xFFB9761A);
  static const anar = Color(0xFFE14D63);
  static const anarDark = Color(0xFFA8304A);
  static const kaghaz = Color(0xFFFBF3E4);
  static const ink = Color(0xFF22303F);
  static const txt = Color(0xFFF3EEE2);
  static const txtDim = Color(0xFFA9BAD4);
  static const line = Color(0x24FBF3E4);
  static const onFiruzeh = Color(0xFF06231F);
  static const onZaferan = Color(0xFF3A2600);

  static const teamA = Color(0xFF3D8BFD);
  static const teamB = Color(0xFFE14D63);
  static const gold = Color(0xFFFFD166);
  static const silver = Color(0xFFC9D3E0);
  static const bronze = Color(0xFFD08C5B);

  static Color team(int t) => t == 0 ? teamA : teamB;
}

/// Ink colours offered to the drawer (the eraser is its own tool).
const kPalette = <Color>[
  C.ink,
  Color(0xFFE14D63),
  Color(0xFFF2A93B),
  Color(0xFFFFD84D),
  Color(0xFF3FA34D),
  Color(0xFF2AB5A6),
  Color(0xFF3D8BFD),
  Color(0xFF254B85),
  Color(0xFF7A4BC4),
  Color(0xFFF06BA8),
  Color(0xFF8B5E34),
  Color(0xFF9AA5B1),
];

const kBrushSizes = <double>[3, 7, 14, 26];
const kTeamNames = ['آبی', 'قرمز'];

ThemeData buildTheme() {
  const family = 'Vazirmatn';
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.lajvard,
    colorScheme: base.colorScheme.copyWith(
      primary: C.firuzeh,
      secondary: C.zaferan,
      surface: C.panel,
      error: C.anar,
    ),
    textTheme: base.textTheme.apply(fontFamily: family, bodyColor: C.txt, displayColor: C.txt),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontFamily: family, fontSize: 14, color: C.txt, height: 1.6),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: C.panel),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.firuzeh : C.txtDim),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.firuzeh.withValues(alpha: .35) : C.panel2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.panel2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.firuzeh, width: 1.6)),
      hintStyle: const TextStyle(color: C.txtDim, fontFamily: family),
    ),
  );
}

/// Persian digits — used everywhere numbers appear.
String fa(Object n) {
  const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

/// Shrinks a little when pressed, clicks and buzzes. Wraps any tappable thing.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.sound = Snd.tap, this.scale = .95});
  final Widget child;
  final VoidCallback? onTap;
  final Snd? sound;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTap: on
            ? () {
                if (widget.sound != null) Sfx.play(widget.sound!);
                Sfx.tick();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The chunky "3D" game button: a coloured face sitting on a darker edge that
/// sinks when pressed.
class GameButton extends StatefulWidget {
  const GameButton(
    this.label, {
    super.key,
    this.onTap,
    this.color = C.firuzeh,
    this.edge = C.firuzehDark,
    this.fg = C.onFiruzeh,
    this.icon,
    this.big = false,
    this.sound = Snd.tap,
  });
  final String label;
  final VoidCallback? onTap;
  final Color color, edge, fg;
  final String? icon;
  final bool big;
  final Snd? sound;

  const GameButton.saffron(String label, {Key? key, VoidCallback? onTap, String? icon, bool big = false})
      : this(label, key: key, onTap: onTap, icon: icon, big: big, color: C.zaferan, edge: C.zaferanDark, fg: C.onZaferan);
  const GameButton.danger(String label, {Key? key, VoidCallback? onTap, String? icon})
      : this(label, key: key, onTap: onTap, icon: icon, color: C.anar, edge: C.anarDark, fg: Colors.white);

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    const depth = 5.0;
    final h = widget.big ? 60.0 : 52.0;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: on ? 1 : .45,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: on ? (_) => setState(() => _down = true) : null,
          onTapCancel: on ? () => setState(() => _down = false) : null,
          onTapUp: on ? (_) => setState(() => _down = false) : null,
          onTap: on
              ? () {
                  if (widget.sound != null) Sfx.play(widget.sound!);
                  Sfx.light();
                  widget.onTap!();
                }
              : null,
          child: SizedBox(
            height: h + depth,
            child: Stack(children: [
              Positioned.fill(
                top: depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: widget.edge, borderRadius: BorderRadius.circular(18)),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: _down ? depth - 1 : 0,
                height: h,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(widget.color, Colors.white, .12)!, widget.color],
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (widget.icon != null) ...[
                      Text(widget.icon!, style: TextStyle(fontSize: widget.big ? 22 : 18)),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: widget.fg, fontSize: widget.big ? 19 : 16.5, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Kept for screens that want the flat filled style.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GameButton(label, onTap: onTap);
}

class GhostButton extends StatelessWidget {
  const GhostButton(this.label, {super.key, this.onTap, this.icon});
  final String label;
  final VoidCallback? onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.line, width: 1.4),
              color: const Color(0x0DFFFFFF),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 16)), const SizedBox(width: 8)],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.txt, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = C.panel, this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border ?? C.line),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: child,
      );
}

/// A selectable pill (modes, settings).
class ChoiceChipX extends StatelessWidget {
  const ChoiceChipX(this.label, {super.key, required this.on, required this.onTap, this.color = C.firuzeh});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          sound: Snd.select,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? color : C.panel2.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? color : C.line),
            ),
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: on ? C.onFiruzeh : C.txt)),
          ),
        ),
      );
}
