import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// One line on the paper. Points are normalised 0..1 so every screen size matches.
class Stroke {
  Stroke({required this.id, required this.color, required this.width, List<Offset>? points})
      : points = points ?? [];
  final int id;
  final Color color;
  final double width; // in board units: 1 = 1 px on a 380 px wide board
  final List<Offset> points;

  bool get isEraser => color.toARGB32() == C.kaghaz.toARGB32();
}

/// The drawing on the paper. The last stroke is "live" and repainted every
/// frame; all earlier strokes are rendered once into a cached picture.
class BoardModel extends ChangeNotifier {
  final List<Stroke> strokes = [];
  int _settledVersion = 0;
  int get settledVersion => _settledVersion;
  bool get isEmpty => strokes.isEmpty;

  Stroke? byId(int id) {
    for (var i = strokes.length - 1; i >= 0; i--) {
      if (strokes[i].id == id) return strokes[i];
    }
    return null;
  }

  int get nextId => strokes.isEmpty ? 1 : strokes.map((s) => s.id).reduce(math.max) + 1;

  void begin(Stroke s) {
    strokes.add(s);
    _settledVersion++; // the previous live stroke is now settled
    notifyListeners();
  }

  void extend(int id, Iterable<Offset> pts, {Color? color, double? width}) {
    var s = strokes.isNotEmpty && strokes.last.id == id ? strokes.last : byId(id);
    if (s == null) {
      s = Stroke(id: id, color: color ?? C.ink, width: width ?? 6);
      strokes.add(s);
      _settledVersion++;
    }
    s.points.addAll(pts);
    if (!identical(s, strokes.last)) _settledVersion++;
    notifyListeners();
  }

  void remove(int id) {
    strokes.removeWhere((s) => s.id == id);
    _settledVersion++;
    notifyListeners();
  }

  Stroke? removeLast() {
    if (strokes.isEmpty) return null;
    final s = strokes.removeLast();
    _settledVersion++;
    notifyListeners();
    return s;
  }

  void clear() {
    strokes.clear();
    _settledVersion++;
    notifyListeners();
  }

  void replaceAll(Iterable<Stroke> all) {
    strokes
      ..clear()
      ..addAll(all);
    _settledVersion++;
    notifyListeners();
  }

  /* ---- picture cache for settled strokes ---- */
  ui.Picture? _pic;
  int _picVersion = -1;
  Size _picSize = Size.zero;

  ui.Picture? settledPicture(Size size) {
    if (strokes.length < 2) return null;
    if (_pic != null && _picVersion == _settledVersion && _picSize == size) return _pic;
    _pic?.dispose();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (var i = 0; i < strokes.length - 1; i++) {
      paintStroke(canvas, strokes[i], size);
    }
    _pic = rec.endRecording();
    _picVersion = _settledVersion;
    _picSize = size;
    return _pic;
  }

  @override
  void dispose() {
    _pic?.dispose();
    super.dispose();
  }
}

/// Smooth curve through the points: quadratic segments between midpoints.
void paintStroke(Canvas canvas, Stroke s, Size size) {
  if (s.points.isEmpty) return;
  final scale = size.width / 380;
  final paint = Paint()
    ..color = s.color
    ..strokeWidth = s.width * scale
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  Offset at(int i) => Offset(s.points[i].dx * size.width, s.points[i].dy * size.height);

  if (s.points.length == 1) {
    canvas.drawCircle(at(0), paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
    return;
  }
  final path = Path()..moveTo(at(0).dx, at(0).dy);
  if (s.points.length == 2) {
    path.lineTo(at(1).dx, at(1).dy);
  } else {
    for (var i = 1; i < s.points.length - 1; i++) {
      final p = at(i), q = at(i + 1);
      path.quadraticBezierTo(p.dx, p.dy, (p.dx + q.dx) / 2, (p.dy + q.dy) / 2);
    }
    final last = at(s.points.length - 1);
    path.lineTo(last.dx, last.dy);
  }
  canvas.drawPath(path, paint);
}

class BoardPainter extends CustomPainter {
  BoardPainter(this.model) : super(repaint: model);
  final BoardModel model;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = C.kaghaz);
    final pic = model.settledPicture(size);
    if (pic != null) canvas.drawPicture(pic);
    if (model.strokes.isNotEmpty) {
      if (pic == null && model.strokes.length >= 2) {
        for (final s in model.strokes) {
          paintStroke(canvas, s, size);
        }
      } else {
        paintStroke(canvas, model.strokes.last, size);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => old.model != model;
}

/// Renders the board to a PNG with the game's name on it (for sharing).
Future<List<int>?> boardToPng(BoardModel model, {String? caption, int width = 1080}) async {
  final height = (width * 1.25).round();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final size = Size(width.toDouble(), height.toDouble());
  canvas.drawRect(Offset.zero & size, Paint()..color = C.kaghaz);
  final boardSize = Size(size.width, size.height - 120);
  for (final s in model.strokes) {
    paintStroke(canvas, s, boardSize);
  }
  canvas.drawRect(Rect.fromLTWH(0, size.height - 120, size.width, 120), Paint()..color = C.lajvard);
  final tp = TextPainter(
    textDirection: TextDirection.rtl,
    text: TextSpan(children: [
      const TextSpan(text: '🎨 نقاشی ', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 46, fontWeight: FontWeight.w900, color: C.txt)),
      const TextSpan(text: 'بکش', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 46, fontWeight: FontWeight.w900, color: C.firuzeh)),
      if (caption != null)
        TextSpan(text: '   $caption', style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 34, fontWeight: FontWeight.w700, color: C.zaferan)),
    ]),
  )..layout(maxWidth: size.width - 60);
  tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 60 - tp.height / 2));
  final img = await rec.endRecording().toImage(width, height);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data?.buffer.asUint8List();
}

/// The paper. Interactive only when [enabled]; reports a finger's points to
/// [onPoints] (first call has isNew = true) and [onEnd] when it lifts.
class DrawingSurface extends StatefulWidget {
  const DrawingSurface({
    super.key,
    required this.model,
    this.enabled = false,
    this.color = C.ink,
    this.width = 6,
    this.onPoints,
    this.onEnd,
  });

  final BoardModel model;
  final bool enabled;
  final Color color;
  final double width;
  final void Function(Stroke stroke, List<Offset> added, bool isNew)? onPoints;
  final void Function(Stroke stroke)? onEnd;

  @override
  State<DrawingSurface> createState() => _DrawingSurfaceState();
}

class _DrawingSurfaceState extends State<DrawingSurface> {
  int? _pointer;
  Stroke? _live;

  Offset _norm(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  void _down(PointerDownEvent e, Size size) {
    if (_pointer != null) return; // one finger draws; a second is ignored
    _pointer = e.pointer;
    final p = _norm(e.localPosition, size);
    final s = Stroke(id: widget.model.nextId, color: widget.color, width: widget.width, points: [p]);
    widget.model.begin(s);
    _live = s;
    widget.onPoints?.call(s, [p], true);
  }

  void _move(PointerMoveEvent e, Size size) {
    if (e.pointer != _pointer || _live == null) return;
    final p = _norm(e.localPosition, size);
    final last = _live!.points.last;
    // skip sub-pixel jitter: keeps messages small and curves clean
    if ((p - last).distance < 1.2 / size.width) return;
    widget.model.extend(_live!.id, [p]);
    widget.onPoints?.call(_live!, [p], false);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final s = _live;
    _live = null;
    if (s != null) widget.onEnd?.call(s);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final board = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: RepaintBoundary(child: CustomPaint(painter: BoardPainter(widget.model), size: size)),
      );
      if (!widget.enabled) return board;
      return Listener(
        onPointerDown: (e) => _down(e, size),
        onPointerMove: (e) => _move(e, size),
        onPointerUp: _up,
        onPointerCancel: _up,
        child: board,
      );
    });
  }
}

/// Batches a live stroke's points for the network: one message every ~40 ms
/// (or sooner when it gets large), coordinates as integers 0..10000.
class StrokeSender {
  StrokeSender(this.send);
  final void Function(Map<String, dynamic> msg) send;

  Stroke? _stroke;
  final List<int> _pending = [];
  bool _sentHead = false;
  Timer? _timer;

  static int _q(double v) => (v * 10000).round().clamp(0, 10000);

  void add(Stroke s, List<Offset> pts, bool isNew) {
    if (isNew || !identical(s, _stroke)) {
      flush();
      _stroke = s;
      _sentHead = false;
    }
    for (final p in pts) {
      _pending
        ..add(_q(p.dx))
        ..add(_q(p.dy));
    }
    if (_pending.length >= 240) {
      flush();
    } else {
      _timer ??= Timer(const Duration(milliseconds: 40), flush);
    }
  }

  void end(Stroke s) {
    if (identical(s, _stroke)) flush();
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final s = _stroke;
    if (s == null || _pending.isEmpty) return;
    while (_pending.isNotEmpty) {
      final n = math.min(_pending.length, 500);
      final chunk = _pending.sublist(0, n);
      _pending.removeRange(0, n);
      send({
        't': 'pts',
        'id': s.id,
        if (!_sentHead) 'c': '#${(s.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        if (!_sentHead) 'w': s.width,
        'p': chunk,
      });
      _sentHead = true;
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _stroke = null;
    _sentHead = false;
  }

  void dispose() => _timer?.cancel();
}
