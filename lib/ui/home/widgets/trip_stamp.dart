import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';

/// A passport-style ink stamp for a finished trip's card: a single worn
/// ring with "DONE" set in the middle. Same worn-ring technique as
/// travelsync's stamp collection (`StampPainter`/`_drawWornRing` in
/// travelsync/lib/UI/profile/profile_screen.dart), simplified to one ring
/// and one word for a small corner mark.
class DoneStamp extends StatelessWidget {
  final Trip trip;
  final double diameter;
  const DoneStamp({super.key, required this.trip, this.diameter = 100});

  // Muted, desaturated tones so the ink reads as faded/aged rather than
  // fresh — and so it's never mistaken for the app's own teal accent or
  // warning red. Deterministic per trip so the same card always gets the
  // same ink.
  static const _inkPalette = [
    Color(0xFF9C5A4A), // faded brick red
    Color(0xFF5B7A8C), // washed-out slate blue
    Color(0xFF6E825A), // muted sage green
    Color(0xFF7C6A8C), // dusty mauve
    Color(0xFF9C8256), // aged amber/ochre
    Color(0xFF5A8484), // weathered teal
  ];

  @override
  Widget build(BuildContext context) {
    final seed = trip.id.hashCode;
    final ink = _inkPalette[seed.abs() % _inkPalette.length];
    // Never dead level — stamped by hand, not printed. Seeded so a card's
    // tilt stays put across rebuilds.
    final tiltRand = math.Random(seed ^ 0x5DEECE66D);
    final tilt = (tiltRand.nextDouble() - 0.5) * 16 * (math.pi / 180);

    return Transform.rotate(
      angle: tilt,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CustomPaint(painter: _StampPainter(seed: seed, ink: ink)),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final int seed;
  final Color ink;

  _StampPainter({required this.seed, required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rand = math.Random(seed * 991 + 7);

    // Worn ring — skips little arcs at random so it looks pressed by hand
    // rather than machine-perfect.
    _drawWornRing(canvas, center, radius, rand);

    // The serif display face reads like hand-set stamp type — the mono
    // label face used elsewhere in the app felt too clean/mechanical here.
    final style = AppText.display(radius * 0.44, color: ink.withValues(alpha: 0.9))
        .copyWith(letterSpacing: 1.4);
    final tp = TextPainter(
      text: TextSpan(text: 'DONE', style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: radius * 1.6);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawWornRing(Canvas canvas, Offset center, double radius, math.Random rand) {
    final paint = Paint()
      ..color = ink.withValues(alpha: 0.8)
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

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) => oldDelegate.ink != ink;
}
