import 'package:flutter/material.dart';

/// Persian ceramic palette: lâjvard chrome, firuzeh accent, saffron highlight,
/// cream drawing surface so the canvas reads as ink on paper.
class C {
  static const lajvard = Color(0xFF12233F);
  static const panel = Color(0xFF172E52);
  static const panel2 = Color(0xFF1F3D6E);
  static const firuzeh = Color(0xFF2AB5A6);
  static const zaferan = Color(0xFFF2A93B);
  static const anar = Color(0xFFE14D63);
  static const kaghaz = Color(0xFFFBF3E4);
  static const ink = Color(0xFF22303F);
  static const txt = Color(0xFFF3EEE2);
  static const txtDim = Color(0xFFA9BAD4);
  static const line = Color(0x24FBF3E4);

  static const teamA = Color(0xFF3D8BFD);
  static const teamB = Color(0xFFE14D63);
}

/// Ink colours offered to the drawer.
const kPalette = <Color>[
  C.ink,
  Color(0xFFE14D63),
  Color(0xFFF2A93B),
  Color(0xFF2AB5A6),
  Color(0xFF254B85),
  Color(0xFF7A4BC4),
  Color(0xFF3FA34D),
  Color(0xFF8B5E34),
  Color(0xFFF06BA8),
  C.kaghaz, // acts as an eraser stroke on the paper
];

const kBrushSizes = <double>[3, 6, 12, 22];

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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.panel2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: C.firuzeh, width: 1.6),
      ),
      hintStyle: const TextStyle(color: C.txtDim, fontFamily: family),
    ),
  );
}

/// Persian digits — used everywhere numbers appear.
String fa(Object n) {
  const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

/// Filled action button used across screens.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onTap, this.color = C.firuzeh, this.fg = const Color(0xFF06231F)});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Opacity(
      opacity: on ? 1 : .45,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(color: C.txt, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.line),
        ),
        child: child,
      );
}
