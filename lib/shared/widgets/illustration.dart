import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../models/models.dart';

class ParkingIllustration extends StatelessWidget {
  final VisualType type;
  final double width;
  final double height;
  const ParkingIllustration(
    this.type, {
    super.key,
    this.width = 104,
    this.height = 76,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _ParkingIllustrationPainter(type),
  );
}

class _ParkingIllustrationPainter extends CustomPainter {
  final VisualType type;
  _ParkingIllustrationPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    paint.color = T.ink;
    canvas.drawRRect(bg, paint);

    paint.color = switch (type) {
      VisualType.garage => T.mintSoft,
      VisualType.privateOutdoor => const Color(0xFFE8E1D4),
      VisualType.courtyard => const Color(0xFFE7F1E8),
      VisualType.practice => const Color(0xFFEAF0F7),
      VisualType.hotel => const Color(0xFFFFE8C4),
      VisualType.office => const Color(0xFFDDE8EF),
      VisualType.gated => const Color(0xFFE6EFEA),
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 10, size.width - 16, size.height - 18),
        const Radius.circular(18),
      ),
      paint,
    );

    _drawGround(canvas, size, paint);
    switch (type) {
      case VisualType.garage:
        _drawGarage(canvas, size, paint, underground: true);
      case VisualType.privateOutdoor:
        _drawOutdoor(canvas, size, paint);
      case VisualType.courtyard:
        _drawCourtyard(canvas, size, paint);
      case VisualType.practice:
        _drawPractice(canvas, size, paint);
      case VisualType.hotel:
        _drawHotel(canvas, size, paint);
      case VisualType.office:
        _drawOffice(canvas, size, paint);
      case VisualType.gated:
        _drawGate(canvas, size, paint);
    }
    paint.color = T.mint;
    canvas.drawCircle(Offset(size.width - 22, 18), 6, paint);
    paint.color = T.ink;
    canvas.drawCircle(Offset(size.width - 22, 18), 2.5, paint);
  }

  void _drawGround(Canvas c, Size s, Paint p) {
    p.color = T.ink.withOpacity(.12);
    p.strokeWidth = 2;
    for (double x = 18; x < s.width - 16; x += 18) {
      c.drawLine(Offset(x, s.height - 18), Offset(x + 10, s.height - 28), p);
    }
  }

  void _drawGarage(Canvas c, Size s, Paint p, {bool underground = false}) {
    p.color = T.ink;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 24, s.width - 36, 30),
        const Radius.circular(8),
      ),
      p,
    );
    p.color = T.mint;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(28, 33, s.width - 56, 16),
        const Radius.circular(4),
      ),
      p,
    );
    p.color = Colors.white;
    c.drawRect(Rect.fromLTWH(34, 36, 7, 10), p);
    c.drawRect(Rect.fromLTWH(s.width - 42, 36, 7, 10), p);
  }

  void _drawOutdoor(Canvas c, Size s, Paint p) {
    _drawCar(c, s, p);
    p.color = T.amber;
    c.drawCircle(Offset(26, 23), 7, p);
  }

  void _drawCourtyard(Canvas c, Size s, Paint p) {
    p.color = T.ink;
    c.drawRect(Rect.fromLTWH(18, 22, 10, 36), p);
    c.drawRect(Rect.fromLTWH(s.width - 28, 22, 10, 36), p);
    _drawCar(c, s, p);
  }

  void _drawPractice(Canvas c, Size s, Paint p) {
    _drawOffice(c, s, p);
    p.color = T.amber;
    c.drawRect(Rect.fromLTWH(27, 27, 15, 5), p);
    c.drawRect(Rect.fromLTWH(32, 22, 5, 15), p);
  }

  void _drawHotel(Canvas c, Size s, Paint p) {
    _drawGarage(c, s, p);
    p.color = T.amber;
    c.drawCircle(Offset(32, 22), 4, p);
    c.drawCircle(Offset(44, 22), 4, p);
  }

  void _drawOffice(Canvas c, Size s, Paint p) {
    p.color = T.ink;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(22, 18, 44, 40),
        const Radius.circular(5),
      ),
      p,
    );
    p.color = Colors.white;
    for (double y = 25; y < 48; y += 10) {
      c.drawRect(Rect.fromLTWH(30, y, 7, 4), p);
      c.drawRect(Rect.fromLTWH(46, y, 7, 4), p);
    }
  }

  void _drawGate(Canvas c, Size s, Paint p) {
    p.color = T.ink;
    c.drawRect(Rect.fromLTWH(21, 26, 6, 32), p);
    c.drawRect(Rect.fromLTWH(s.width - 27, 26, 6, 32), p);
    p.strokeWidth = 4;
    c.drawLine(Offset(28, 34), Offset(s.width - 28, 50), p);
    _drawCar(c, s, p);
  }

  void _drawCar(Canvas c, Size s, Paint p) {
    p.color = T.ink;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(34, 35, 38, 18),
        const Radius.circular(8),
      ),
      p,
    );
    p.color = T.mint;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(42, 28, 22, 15),
        const Radius.circular(5),
      ),
      p,
    );
    p.color = Colors.white;
    c.drawCircle(Offset(43, 54), 3, p);
    c.drawCircle(Offset(64, 54), 3, p);
  }

  @override
  bool shouldRepaint(covariant _ParkingIllustrationPainter oldDelegate) =>
      oldDelegate.type != type;
}
