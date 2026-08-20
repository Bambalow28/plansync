import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';

/// A passport-style ink stamp across a finished trip's card: a worn double
/// ring, hand-set arc type along the rim, and a postmark date/star/rule at
/// center. Same technique as travelsync's stamp collection
/// (`StampPainter`/`_drawArcText`/`_drawWornRing`/`_drawStar` in
/// travelsync/lib/UI/profile/profile_screen.dart), ported here for a single
/// mark on one card instead of a whole scattered collection.
class DoneStamp extends StatelessWidget {
  final Trip trip;
  const DoneStamp({super.key, required this.trip});

  // Muted, desaturated tones so the ink reads as faded/aged rather than
  // fresh — and so it's never mistaken for the app's own teal accent or
  // warning red. Same palette as travelsync, picked deterministically per
  // trip so the same card always gets the same ink.
  static const _inkPalette = [
    Color(0xFF9C5A4A), // faded brick red
    Color(0xFF5B7A8C), // washed-out slate blue
    Color(0xFF6E825A), // muted sage green
    Color(0xFF7C6A8C), // dusty mauve
    Color(0xFF9C8256), // aged amber/ochre
    Color(0xFF5A8484), // weathered teal
  ];

  static const double _diameter = 100;

  @override
  Widget build(BuildContext context) {
    final seed = trip.id.hashCode;
    final ink = _inkPalette[seed.abs() % _inkPalette.length];
    // Never dead level — stamped by hand, not printed. Seeded so a card's
    // tilt stays put across rebuilds.
    final tiltRand = math.Random(seed ^ 0x5DEECE66D);
    final tilt = (tiltRand.nextDouble() - 0.5) * 16 * (math.pi / 180);
    final country = (trip.destination?.country.trim().isNotEmpty ?? false)
        ? trip.destination!.country.toUpperCase()
        : 'PLANSYNC';
    final date = DateFormat('MMM yyyy').format(trip.endDate).toUpperCase();

    return Center(
      child: Transform.rotate(
        angle: tilt,
        child: SizedBox(
          width: _diameter,
          height: _diameter,
          child: CustomPaint(
            painter: _StampPainter(
              country: country,
              date: date,
              seed: seed,
              ink: ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final String country;
  final String date;
  final int seed;
  final Color ink;

  _StampPainter({
    required this.country,
    required this.date,
    required this.seed,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rand = math.Random(seed * 991 + 7);

    // Worn double ring — skips little arcs at random so it looks pressed by
    // hand rather than machine-perfect.
    _drawWornRing(canvas, center, radius, rand, alpha: 0.8);
    _drawWornRing(canvas, center, radius - 6, rand, alpha: 0.55);

    _drawArcText(
      canvas,
      'DONE',
      center,
      radius: radius - 6,
      baseAngle: -math.pi / 2,
      clockwise: true,
    );
    _drawArcText(
      canvas,
      country,
      center,
      radius: radius - 6,
      baseAngle: math.pi / 2,
      clockwise: false,
    );

    // End date, centered, with a star and a thin rule under it like a
    // postmark date line.
    final dateStyle = AppText.label(
      radius * 0.19,
      color: ink.withValues(alpha: 0.9),
      tracking: 0.3,
    ).copyWith(fontWeight: FontWeight.bold);
    final tp = TextPainter(
      text: TextSpan(text: date, style: dateStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: radius * 1.6);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    _drawStar(
      canvas,
      center - Offset(0, tp.height / 2 + radius * 0.16),
      radius * 0.09,
    );

    canvas.drawLine(
      center + Offset(-radius * 0.42, radius * 0.26),
      center + Offset(radius * 0.42, radius * 0.26),
      Paint()
        ..color = ink.withValues(alpha: 0.4)
        ..strokeWidth = 0.9,
    );
  }

  /// Small 5-point star, like the one stamped above a date on a real visa/
  /// postmark stamp.
  void _drawStar(Canvas canvas, Offset center, double size) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? size : size * 0.42;
      final a = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = ink.withValues(alpha: 0.85));
  }

  void _drawWornRing(
    Canvas canvas,
    Offset center,
    double radius,
    math.Random rand, {
    required double alpha,
  }) {
    final paint = Paint()
      ..color = ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const stepDeg = 4.0;
    for (var deg = 0.0; deg < 360; deg += stepDeg) {
      if (rand.nextDouble() < 0.1) continue; // gap: worn/faded ink
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        deg * math.pi / 180,
        stepDeg * math.pi / 180,
        false,
        paint,
      );
    }
  }

  /// Draws [text] curved along a circle of [radius] centered at [center].
  /// [clockwise] true curves it over the top rim (letters upright, outward);
  /// false curves it under the bottom rim (letters upright, inward) so both
  /// read normally to the viewer, as on a real circular stamp.
  void _drawArcText(
    Canvas canvas,
    String text,
    Offset center, {
    required double radius,
    required double baseAngle,
    required bool clockwise,
  }) {
    if (text.isEmpty || text.length == 1) return;
    const maxSpan = 2.6; // radians (~150°)
    const baseFontScale = 0.30;
    const baseAngleStep = 0.34;
    final sizeRatio = text.length <= 8
        ? 1 + 0.03 * (8 - text.length)
        : 8 / text.length;
    final fontSize = radius * baseFontScale * sizeRatio;
    final anglePerChar = math.min(
      maxSpan / (text.length - 1),
      baseAngleStep * sizeRatio,
    );
    final totalSpan = anglePerChar * (text.length - 1);
    final style = AppText.label(
      fontSize,
      color: ink.withValues(alpha: 0.88),
      tracking: 0.5,
    ).copyWith(fontWeight: FontWeight.bold);
    // Glyphs are centered on this circle, so inset it by half a cap-height
    // (scaled with fontSize) — otherwise the outer half of each letter pokes
    // past the ring it's meant to sit inside.
    final textRadius = radius - fontSize * 0.6;

    for (var i = 0; i < text.length; i++) {
      final offset = -totalSpan / 2 + anglePerChar * i;
      final angle = clockwise ? baseAngle + offset : baseAngle - offset;
      final pos = Offset(
        center.dx + textRadius * math.cos(angle),
        center.dy + textRadius * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(clockwise ? angle + math.pi / 2 : angle - math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) =>
      oldDelegate.country != country ||
      oldDelegate.date != date ||
      oldDelegate.ink != ink;
}
