import 'dart:math';

import 'package:flutter/material.dart';

/// Icons drawn in code in the style of the painted ones: chunky shapes, an
/// ink outline and two or three shades lit from the top-left.
enum FFGlyph {
  soul,
  star,
  starEmpty,
  chest,
  key,
  lock,
  gear,
  scroll,
  calendar,
  bag,
  shield,
  frost,
  eye,
  flame,
  crown,
  gift,
  back,
  close,
  map,
  plus,
  check,
  play,
  moon,
  infinity,
  film,
  music,
  sound,
  soundOff,
  hourglass,
  door,
}

class FFIcon extends StatelessWidget {
  const FFIcon(this.glyph, {this.size = 24, this.color, super.key});

  final FFGlyph glyph;
  final double size;

  /// Overrides the main fill (used to grey out locked things).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(glyph, color)),
    );
  }
}

const _ink = Color(0xFF16151F);
const _bone = Color(0xFFF0E6D2);
const _bone2 = Color(0xFFD8C3A0);
const _boneDim = Color(0xFFB39572);
const _gold = Color(0xFFFFE08A);
const _amber = Color(0xFFF2B544);
const _amberDark = Color(0xFFC98A2E);
const _rust = Color(0xFF9C5A2B);
const _wood = Color(0xFF6B3F24);
const _woodDark = Color(0xFF3E2A20);
const _spiritHi = Color(0xFFE4F2FF);
const _spirit = Color(0xFF9CC8F0);
const _spiritDark = Color(0xFF6A94C0);
const _blood = Color(0xFFE03A32);
const _blood2 = Color(0xFFB0202A);
const _stone = Color(0xFF7884A0);
const _stoneDark = Color(0xFF55627E);
const _slate = Color(0xFF34344A);

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.tint);

  final FFGlyph glyph;
  final Color? tint;

  late double _u;
  late Canvas _c;

  Paint _fill(Color a, [Color? b, Rect? bounds]) {
    final paint = Paint()..isAntiAlias = true;
    final color = tint ?? a;
    if (b != null && bounds != null && tint == null) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [a, b],
      ).createShader(bounds);
    } else {
      paint.color = color;
    }
    return paint;
  }

  Paint get _outline => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7 * _u
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint _line(Color color, double width) => Paint()
    ..color = tint ?? color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width * _u
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Offset _p(double x, double y) => Offset(x * _u, y * _u);
  Rect _r(double l, double t, double w, double h) =>
      Rect.fromLTWH(l * _u, t * _u, w * _u, h * _u);

  void _shape(Path path, Color a, [Color? b]) {
    _c.drawPath(path, _fill(a, b, path.getBounds()));
    _c.drawPath(path, _outline);
  }

  void _rrect(Rect r, double radius, Color a, [Color? b]) {
    _shape(
      Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius * _u))),
      a,
      b,
    );
  }

  void _circle(Offset c, double r, Color a, [Color? b]) {
    _shape(Path()..addOval(Rect.fromCircle(center: c, radius: r * _u)), a, b);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    _u = size.width / 24;
    switch (glyph) {
      case FFGlyph.soul:
        _soul();
      case FFGlyph.star:
        _star(_gold, _amberDark, glow: true);
      case FFGlyph.starEmpty:
        _star(_slate, const Color(0xFF23222F));
      case FFGlyph.chest:
        _chest();
      case FFGlyph.key:
        _key();
      case FFGlyph.lock:
        _lock();
      case FFGlyph.gear:
        _gear();
      case FFGlyph.scroll:
        _scroll();
      case FFGlyph.calendar:
        _calendar();
      case FFGlyph.bag:
        _bag();
      case FFGlyph.shield:
        _shield();
      case FFGlyph.frost:
        _frost();
      case FFGlyph.eye:
        _eye();
      case FFGlyph.flame:
        _flame(_gold, _amber, const Color(0xFFFF7A2E));
      case FFGlyph.crown:
        _crown();
      case FFGlyph.gift:
        _gift();
      case FFGlyph.back:
        _arrow(left: true);
      case FFGlyph.close:
        _close();
      case FFGlyph.map:
        _map();
      case FFGlyph.plus:
        _plus();
      case FFGlyph.check:
        _check();
      case FFGlyph.play:
        _play();
      case FFGlyph.moon:
        _moon();
      case FFGlyph.infinity:
        _infinity();
      case FFGlyph.film:
        _film();
      case FFGlyph.music:
        _music();
      case FFGlyph.sound:
        _sound(off: false);
      case FFGlyph.soundOff:
        _sound(off: true);
      case FFGlyph.hourglass:
        _hourglass();
      case FFGlyph.door:
        _door();
    }
  }

  void _soul() {
    final glow = Paint()
      ..color = (tint ?? _spirit).withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _u);
    _c.drawCircle(_p(12, 14), 8 * _u, glow);
    final flame = Path()
      ..moveTo(12 * _u, 2 * _u)
      ..cubicTo(15 * _u, 6 * _u, 20 * _u, 9 * _u, 19 * _u, 15 * _u)
      ..cubicTo(18.5 * _u, 19.5 * _u, 15 * _u, 22 * _u, 12 * _u, 22 * _u)
      ..cubicTo(8.5 * _u, 22 * _u, 5 * _u, 19.5 * _u, 5 * _u, 15.5 * _u)
      ..cubicTo(5 * _u, 12 * _u, 8 * _u, 10 * _u, 9 * _u, 7 * _u)
      ..cubicTo(10.5 * _u, 9 * _u, 11 * _u, 10 * _u, 11.5 * _u, 11 * _u)
      ..cubicTo(12.5 * _u, 8 * _u, 12.5 * _u, 5 * _u, 12 * _u, 2 * _u)
      ..close();
    _shape(flame, _spiritHi, _spiritDark);
    _c.drawOval(
      _r(8.5, 13, 7, 7.5),
      Paint()..color = (tint ?? Colors.white).withValues(alpha: 0.7),
    );
    _c.drawCircle(_p(10.4, 16.2), 0.95 * _u, Paint()..color = _ink);
    _c.drawCircle(_p(13.6, 16.2), 0.95 * _u, Paint()..color = _ink);
  }

  Path _starPath(double cx, double cy, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cx + cos(a) * r, cy + sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx * _u, pt.dy * _u);
      } else {
        path.lineTo(pt.dx * _u, pt.dy * _u);
      }
    }
    return path..close();
  }

  void _star(Color a, Color b, {bool glow = false}) {
    if (glow && tint == null) {
      _c.drawCircle(
        _p(12, 12.5),
        9 * _u,
        Paint()
          ..color = _amber.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _u),
      );
    }
    _shape(_starPath(12, 12.8, 10.5, 4.6), a, b);
    if (glow) {
      _c.drawPath(
        _starPath(10.8, 11.2, 3.2, 1.4),
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  void _chest() {
    _rrect(_r(3, 10, 18, 11), 1.5, _wood, _woodDark);
    final lid = Path()
      ..moveTo(3 * _u, 11 * _u)
      ..lineTo(3 * _u, 8 * _u)
      ..quadraticBezierTo(12 * _u, 1.5 * _u, 21 * _u, 8 * _u)
      ..lineTo(21 * _u, 11 * _u)
      ..close();
    _shape(lid, _rust, _wood);
    final band = _fill(_amber, _amberDark, _r(0, 0, 24, 24));
    _c.drawRect(_r(6, 5, 2.2, 16), band);
    _c.drawRect(_r(15.8, 5, 2.2, 16), band);
    _c.drawRect(_r(6, 5, 2.2, 16), _outline..strokeWidth = 1.1 * _u);
    _c.drawRect(_r(15.8, 5, 2.2, 16), _outline..strokeWidth = 1.1 * _u);
    _rrect(_r(10, 9.5, 4, 4.5), 0.8, _gold, _amberDark);
    _c.drawCircle(_p(12, 11.5), 0.7 * _u, Paint()..color = _ink);
  }

  void _key() {
    final p = _line(_ink, 5.2);
    _c.drawLine(_p(10, 13), _p(20, 13), p);
    _c.drawLine(_p(17, 13), _p(17, 18), p);
    _c.drawLine(_p(20, 13), _p(20, 17), p);
    final q = _line(_gold, 2.6);
    _c.drawLine(_p(10, 13), _p(20, 13), q);
    _c.drawLine(_p(17, 13), _p(17, 18), q);
    _c.drawLine(_p(20, 13), _p(20, 17), q);
    _circle(_p(7, 13), 5, _gold, _amberDark);
    _circle(_p(7, 13), 1.8, _woodDark);
  }

  void _lock() {
    final shackle = _line(_ink, 5);
    _c.drawArc(_r(6.5, 3, 11, 12), pi, pi, false, shackle);
    _c.drawArc(_r(6.5, 3, 11, 12), pi, pi, false, _line(_stone, 2.4));
    _rrect(_r(4, 10, 16, 12), 2, _stone, _stoneDark);
    _circle(_p(12, 15), 1.8, _ink);
    _c.drawRect(_r(11.3, 15.5, 1.4, 3.5), Paint()..color = _ink);
  }

  void _gear() {
    final path = Path();
    const teeth = 8;
    for (var i = 0; i < teeth * 2; i++) {
      final r = i.isEven ? 10.5 : 8.0;
      final a0 = i * pi / teeth - pi / (teeth * 2);
      final a1 = a0 + pi / teeth;
      final p0 = Offset(12 + cos(a0) * r, 12 + sin(a0) * r);
      final p1 = Offset(12 + cos(a1) * r, 12 + sin(a1) * r);
      if (i == 0) path.moveTo(p0.dx * _u, p0.dy * _u);
      path.lineTo(p0.dx * _u, p0.dy * _u);
      path.lineTo(p1.dx * _u, p1.dy * _u);
    }
    path.close();
    _shape(path, _bone, _boneDim);
    _circle(_p(12, 12), 3.4, _slate);
  }

  void _scroll() {
    _rrect(_r(5, 4, 14, 16), 1, _bone, _bone2);
    _rrect(_r(3, 2.5, 18, 4), 2, _boneDim, const Color(0xFF8A6B50));
    _rrect(_r(3, 17.5, 18, 4), 2, _boneDim, const Color(0xFF8A6B50));
    final l = _line(const Color(0xFF8A6B50), 1.4);
    _c.drawLine(_p(8, 9.5), _p(16, 9.5), l);
    _c.drawLine(_p(8, 12.5), _p(16, 12.5), l);
    _c.drawLine(_p(8, 15), _p(13, 15), l);
  }

  void _calendar() {
    _rrect(_r(3, 4.5, 18, 17), 2, _bone, _bone2);
    final top = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          _r(3, 4.5, 18, 5.5),
          topLeft: Radius.circular(2 * _u),
          topRight: Radius.circular(2 * _u),
        ),
      );
    _shape(top, _blood, _blood2);
    _rrect(_r(6.5, 2, 2.4, 5), 1, _stone);
    _rrect(_r(15.1, 2, 2.4, 5), 1, _stone);
    final dot = Paint()..color = tint ?? const Color(0xFF8A6B50);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        _c.drawRect(_r(6.5 + col * 4, 12.5 + row * 4, 2.6, 2.6), dot);
      }
    }
  }

  void _bag() {
    final sack = Path()
      ..moveTo(8 * _u, 8 * _u)
      ..cubicTo(2 * _u, 12 * _u, 2 * _u, 22 * _u, 12 * _u, 22 * _u)
      ..cubicTo(22 * _u, 22 * _u, 22 * _u, 12 * _u, 16 * _u, 8 * _u)
      ..close();
    _shape(sack, const Color(0xFFB08A60), const Color(0xFF6B4A30));
    final neck = Path()
      ..moveTo(8 * _u, 8.5 * _u)
      ..lineTo(6.5 * _u, 3 * _u)
      ..lineTo(12 * _u, 5 * _u)
      ..lineTo(17.5 * _u, 3 * _u)
      ..lineTo(16 * _u, 8.5 * _u)
      ..close();
    _shape(neck, const Color(0xFFB08A60), const Color(0xFF8A6B50));
    _c.drawLine(_p(8, 8.5), _p(16, 8.5), _line(_amber, 1.8));
    _circle(_p(12, 15.5), 3, _spiritHi, _spirit);
  }

  void _shield() {
    final path = Path()
      ..moveTo(12 * _u, 2 * _u)
      ..lineTo(20.5 * _u, 5 * _u)
      ..cubicTo(20.5 * _u, 13 * _u, 18 * _u, 18.5 * _u, 12 * _u, 22 * _u)
      ..cubicTo(6 * _u, 18.5 * _u, 3.5 * _u, 13 * _u, 3.5 * _u, 5 * _u)
      ..close();
    _shape(path, _spiritHi, _spiritDark);
    final cross = _line(_gold, 2.4);
    _c.drawLine(_p(12, 6.5), _p(12, 17.5), _line(_ink, 4.4));
    _c.drawLine(_p(8, 10.5), _p(16, 10.5), _line(_ink, 4.4));
    _c.drawLine(_p(12, 6.5), _p(12, 17.5), cross);
    _c.drawLine(_p(8, 10.5), _p(16, 10.5), cross);
  }

  void _frost() {
    final glow = Paint()
      ..color = (tint ?? _spirit).withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _u);
    _c.drawCircle(_p(12, 12), 8 * _u, glow);
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3;
      final d = Offset(cos(a), sin(a)) * 9.5;
      final from = Offset(12 - d.dx, 12 - d.dy);
      final to = Offset(12 + d.dx, 12 + d.dy);
      _c.drawLine(_p(from.dx, from.dy), _p(to.dx, to.dy), _line(_ink, 4.4));
    }
    for (var i = 0; i < 3; i++) {
      final a = i * pi / 3;
      final d = Offset(cos(a), sin(a)) * 9.5;
      _c.drawLine(
        _p(12 - d.dx, 12 - d.dy),
        _p(12 + d.dx, 12 + d.dy),
        _line(_spiritHi, 2.2),
      );
    }
    _circle(_p(12, 12), 2.4, Colors.white, _spirit);
  }

  void _eye() {
    final path = Path()
      ..moveTo(2 * _u, 12 * _u)
      ..quadraticBezierTo(12 * _u, 1.5 * _u, 22 * _u, 12 * _u)
      ..quadraticBezierTo(12 * _u, 22.5 * _u, 2 * _u, 12 * _u)
      ..close();
    _shape(path, _bone, _bone2);
    _circle(_p(12, 12), 4.6, _amber, _rust);
    _circle(_p(12, 12), 2, _ink);
    _c.drawCircle(_p(13.3, 10.6), 1 * _u, Paint()..color = Colors.white);
  }

  void _flame(Color hi, Color mid, Color low) {
    final glow = Paint()
      ..color = (tint ?? mid).withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _u);
    _c.drawCircle(_p(12, 15), 7 * _u, glow);
    final outer = Path()
      ..moveTo(12 * _u, 1.5 * _u)
      ..cubicTo(14 * _u, 6 * _u, 20 * _u, 9 * _u, 19.5 * _u, 15 * _u)
      ..cubicTo(19 * _u, 20 * _u, 15.5 * _u, 22.5 * _u, 12 * _u, 22.5 * _u)
      ..cubicTo(8.5 * _u, 22.5 * _u, 4.5 * _u, 20 * _u, 4.5 * _u, 15 * _u)
      ..cubicTo(4.5 * _u, 11 * _u, 8 * _u, 9 * _u, 9.5 * _u, 5.5 * _u)
      ..cubicTo(10.5 * _u, 8 * _u, 11 * _u, 9 * _u, 11.5 * _u, 10 * _u)
      ..cubicTo(12.5 * _u, 7.5 * _u, 12.5 * _u, 4.5 * _u, 12 * _u, 1.5 * _u)
      ..close();
    _shape(outer, mid, low);
    final inner = Path()
      ..moveTo(12 * _u, 10 * _u)
      ..cubicTo(14.5 * _u, 13 * _u, 16 * _u, 15 * _u, 15.5 * _u, 18 * _u)
      ..cubicTo(15 * _u, 20.5 * _u, 9 * _u, 20.5 * _u, 8.5 * _u, 18 * _u)
      ..cubicTo(8 * _u, 15.5 * _u, 10.5 * _u, 13.5 * _u, 12 * _u, 10 * _u)
      ..close();
    _c.drawPath(inner, Paint()..color = tint ?? hi);
  }

  void _crown() {
    final path = Path()
      ..moveTo(3 * _u, 8 * _u)
      ..lineTo(7.5 * _u, 13 * _u)
      ..lineTo(12 * _u, 4.5 * _u)
      ..lineTo(16.5 * _u, 13 * _u)
      ..lineTo(21 * _u, 8 * _u)
      ..lineTo(19.5 * _u, 19 * _u)
      ..lineTo(4.5 * _u, 19 * _u)
      ..close();
    _shape(path, _gold, _amberDark);
    _circle(_p(12, 15), 1.6, _blood);
    _circle(_p(7.2, 16), 1.1, _spirit);
    _circle(_p(16.8, 16), 1.1, _spirit);
  }

  void _gift() {
    _rrect(_r(3.5, 10, 17, 11.5), 1.5, _blood, _blood2);
    _rrect(_r(2.5, 7, 19, 4.5), 1.5, _blood, _blood2);
    _c.drawRect(
      _r(10.6, 7, 2.8, 14.5),
      _fill(_gold, _amberDark, _r(0, 0, 24, 24)),
    );
    _c.drawRect(_r(10.6, 7, 2.8, 14.5), _outline..strokeWidth = 1.1 * _u);
    final bow = _line(_ink, 4);
    _c.drawArc(_r(6, 2.5, 6, 5.5), 0, pi * 2, false, bow);
    _c.drawArc(_r(12, 2.5, 6, 5.5), 0, pi * 2, false, bow);
    _c.drawArc(_r(6, 2.5, 6, 5.5), 0, pi * 2, false, _line(_gold, 1.8));
    _c.drawArc(_r(12, 2.5, 6, 5.5), 0, pi * 2, false, _line(_gold, 1.8));
  }

  void _arrow({required bool left}) {
    final path = Path()
      ..moveTo(3 * _u, 12 * _u)
      ..lineTo(11 * _u, 4 * _u)
      ..lineTo(11 * _u, 8.5 * _u)
      ..lineTo(21 * _u, 8.5 * _u)
      ..lineTo(21 * _u, 15.5 * _u)
      ..lineTo(11 * _u, 15.5 * _u)
      ..lineTo(11 * _u, 20 * _u)
      ..close();
    if (!left) {
      _c.save();
      _c.translate(24 * _u, 0);
      _c.scale(-1, 1);
    }
    _shape(path, _bone, _boneDim);
    if (!left) _c.restore();
  }

  void _close() {
    _c.drawLine(_p(5.5, 5.5), _p(18.5, 18.5), _line(_ink, 6.5));
    _c.drawLine(_p(18.5, 5.5), _p(5.5, 18.5), _line(_ink, 6.5));
    _c.drawLine(_p(5.5, 5.5), _p(18.5, 18.5), _line(_bone, 3.2));
    _c.drawLine(_p(18.5, 5.5), _p(5.5, 18.5), _line(_bone, 3.2));
  }

  void _map() {
    final path = Path()
      ..moveTo(2.5 * _u, 5.5 * _u)
      ..lineTo(8.5 * _u, 3 * _u)
      ..lineTo(15.5 * _u, 5.5 * _u)
      ..lineTo(21.5 * _u, 3 * _u)
      ..lineTo(21.5 * _u, 18.5 * _u)
      ..lineTo(15.5 * _u, 21 * _u)
      ..lineTo(8.5 * _u, 18.5 * _u)
      ..lineTo(2.5 * _u, 21 * _u)
      ..close();
    _shape(path, _bone, _bone2);
    final fold = _line(_boneDim, 1.2);
    _c.drawLine(_p(8.5, 3), _p(8.5, 18.5), fold);
    _c.drawLine(_p(15.5, 5.5), _p(15.5, 21), fold);
    final trail = Paint()
      ..color = tint ?? _blood2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * _u;
    final dash = Path()
      ..moveTo(5 * _u, 16 * _u)
      ..quadraticBezierTo(10 * _u, 9 * _u, 14 * _u, 13 * _u)
      ..quadraticBezierTo(17 * _u, 16 * _u, 18.5 * _u, 8 * _u);
    _c.drawPath(dash, trail);
    _c.drawLine(_p(17, 6.5), _p(20, 9.5), _line(_blood, 1.8));
    _c.drawLine(_p(20, 6.5), _p(17, 9.5), _line(_blood, 1.8));
  }

  void _plus() {
    _c.drawLine(_p(12, 4), _p(12, 20), _line(_ink, 7));
    _c.drawLine(_p(4, 12), _p(20, 12), _line(_ink, 7));
    _c.drawLine(_p(12, 4), _p(12, 20), _line(_amber, 3.6));
    _c.drawLine(_p(4, 12), _p(20, 12), _line(_amber, 3.6));
  }

  void _check() {
    final path = Path()
      ..moveTo(3.5 * _u, 12.5 * _u)
      ..lineTo(9.5 * _u, 18.5 * _u)
      ..lineTo(20.5 * _u, 5.5 * _u);
    _c.drawPath(path, _line(_ink, 6.5));
    _c.drawPath(path, _line(_gold, 3.2));
  }

  void _play() {
    final path = Path()
      ..moveTo(6 * _u, 3.5 * _u)
      ..lineTo(20.5 * _u, 12 * _u)
      ..lineTo(6 * _u, 20.5 * _u)
      ..close();
    _shape(path, _bone, _boneDim);
  }

  void _moon() {
    final glow = Paint()
      ..color = (tint ?? _blood).withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _u);
    _c.drawCircle(_p(12, 12), 9 * _u, glow);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(_r(3, 3, 18, 18)),
      Path()..addOval(_r(8.5, 0.5, 15, 15)),
    );
    _shape(moon, const Color(0xFFFF6B5E), _blood2);
  }

  void _infinity() {
    final path = Path()
      ..moveTo(12 * _u, 12 * _u)
      ..cubicTo(9 * _u, 7 * _u, 3 * _u, 7 * _u, 3 * _u, 12 * _u)
      ..cubicTo(3 * _u, 17 * _u, 9 * _u, 17 * _u, 12 * _u, 12 * _u)
      ..cubicTo(15 * _u, 7 * _u, 21 * _u, 7 * _u, 21 * _u, 12 * _u)
      ..cubicTo(21 * _u, 17 * _u, 15 * _u, 17 * _u, 12 * _u, 12 * _u);
    _c.drawPath(path, _line(_ink, 6));
    _c.drawPath(path, _line(_spirit, 3));
  }

  void _film() {
    _rrect(_r(2.5, 6, 14, 12), 2, _stone, _stoneDark);
    final cam = Path()
      ..moveTo(16.5 * _u, 10 * _u)
      ..lineTo(21.5 * _u, 7 * _u)
      ..lineTo(21.5 * _u, 17 * _u)
      ..lineTo(16.5 * _u, 14 * _u)
      ..close();
    _shape(cam, _stone, _stoneDark);
    _circle(_p(9.5, 12), 2.6, _blood, _blood2);
  }

  void _music() {
    _c.drawLine(_p(9, 17), _p(9, 5), _line(_ink, 4));
    _c.drawLine(_p(18, 15), _p(18, 3.5), _line(_ink, 4));
    _c.drawLine(_p(9, 5), _p(18, 3.5), _line(_ink, 5));
    _c.drawLine(_p(9, 17), _p(9, 5), _line(_bone, 1.8));
    _c.drawLine(_p(18, 15), _p(18, 3.5), _line(_bone, 1.8));
    _c.drawLine(_p(9, 5), _p(18, 3.5), _line(_bone, 2.6));
    _c.save();
    _c.translate(6.5 * _u, 17.5 * _u);
    _c.rotate(-0.4);
    _shape(
      Path()..addOval(
        Rect.fromCenter(center: Offset.zero, width: 6.5 * _u, height: 4.8 * _u),
      ),
      _bone,
      _boneDim,
    );
    _c.restore();
    _c.save();
    _c.translate(15.5 * _u, 15.5 * _u);
    _c.rotate(-0.4);
    _shape(
      Path()..addOval(
        Rect.fromCenter(center: Offset.zero, width: 6.5 * _u, height: 4.8 * _u),
      ),
      _bone,
      _boneDim,
    );
    _c.restore();
  }

  void _sound({required bool off}) {
    final body = Path()
      ..moveTo(3 * _u, 9 * _u)
      ..lineTo(7.5 * _u, 9 * _u)
      ..lineTo(13 * _u, 4 * _u)
      ..lineTo(13 * _u, 20 * _u)
      ..lineTo(7.5 * _u, 15 * _u)
      ..lineTo(3 * _u, 15 * _u)
      ..close();
    _shape(body, _bone, _boneDim);
    if (off) {
      _c.drawLine(_p(15.5, 8.5), _p(21.5, 15.5), _line(_ink, 4.5));
      _c.drawLine(_p(21.5, 8.5), _p(15.5, 15.5), _line(_ink, 4.5));
      _c.drawLine(_p(15.5, 8.5), _p(21.5, 15.5), _line(_blood, 2.2));
      _c.drawLine(_p(21.5, 8.5), _p(15.5, 15.5), _line(_blood, 2.2));
    } else {
      _c.drawArc(_r(11, 8, 7, 8), -0.9, 1.8, false, _line(_ink, 4));
      _c.drawArc(_r(11, 5, 10.5, 14), -0.9, 1.8, false, _line(_ink, 4));
      _c.drawArc(_r(11, 8, 7, 8), -0.9, 1.8, false, _line(_amber, 2));
      _c.drawArc(_r(11, 5, 10.5, 14), -0.9, 1.8, false, _line(_amber, 2));
    }
  }

  void _hourglass() {
    _rrect(_r(4.5, 2, 15, 3), 1, _wood, _woodDark);
    _rrect(_r(4.5, 19, 15, 3), 1, _wood, _woodDark);
    final glass = Path()
      ..moveTo(6.5 * _u, 5 * _u)
      ..lineTo(17.5 * _u, 5 * _u)
      ..quadraticBezierTo(17.5 * _u, 10 * _u, 13 * _u, 12 * _u)
      ..quadraticBezierTo(17.5 * _u, 14 * _u, 17.5 * _u, 19 * _u)
      ..lineTo(6.5 * _u, 19 * _u)
      ..quadraticBezierTo(6.5 * _u, 14 * _u, 11 * _u, 12 * _u)
      ..quadraticBezierTo(6.5 * _u, 10 * _u, 6.5 * _u, 5 * _u)
      ..close();
    _shape(glass, _spiritHi.withValues(alpha: 0.9), _spirit);
    final sand = Path()
      ..moveTo(8 * _u, 18.6 * _u)
      ..quadraticBezierTo(12 * _u, 13.5 * _u, 16 * _u, 18.6 * _u)
      ..close();
    _c.drawPath(sand, Paint()..color = tint ?? _amber);
    _c.drawPath(
      Path()
        ..moveTo(8.5 * _u, 6.5 * _u)
        ..lineTo(15.5 * _u, 6.5 * _u)
        ..lineTo(12 * _u, 10.5 * _u)
        ..close(),
      Paint()..color = tint ?? _amber,
    );
  }

  void _door() {
    final arch = Path()
      ..moveTo(5 * _u, 22 * _u)
      ..lineTo(5 * _u, 10 * _u)
      ..arcToPoint(_p(19, 10), radius: Radius.circular(7 * _u))
      ..lineTo(19 * _u, 22 * _u)
      ..close();
    _shape(arch, _stone, _stoneDark);
    final inner = Path()
      ..moveTo(8 * _u, 22 * _u)
      ..lineTo(8 * _u, 11 * _u)
      ..arcToPoint(_p(16, 11), radius: Radius.circular(4 * _u))
      ..lineTo(16 * _u, 22 * _u)
      ..close();
    _c.drawPath(inner, Paint()..color = tint ?? _gold);
    _c.drawPath(inner, _outline..strokeWidth = 1.2 * _u);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.tint != tint;
}

/// The icon for a power-up (by its [BoostType] name).
FFGlyph boostGlyphFor(String boostName) => switch (boostName) {
  'shield' => FFGlyph.shield,
  'hourglass' => FFGlyph.hourglass,
  'frost' => FFGlyph.frost,
  'seer' => FFGlyph.eye,
  _ => FFGlyph.soul,
};

/// Paints [glyph] straight onto [canvas], centred on [center], [size] wide
/// (for drawing icons inside the maze painter).
void paintFFGlyph(Canvas canvas, FFGlyph glyph, Offset center, double size) {
  canvas.save();
  canvas.translate(center.dx - size / 2, center.dy - size / 2);
  _GlyphPainter(glyph, null).paint(canvas, Size.square(size));
  canvas.restore();
}
