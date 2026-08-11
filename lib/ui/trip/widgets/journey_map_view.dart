import 'package:flutter/material.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Trip Review layout: a single continuous rail — one dot per day — with each
/// day condensed to a route sentence (its plan titles joined by arrows).
class JourneyMapView extends StatelessWidget {
  final Trip trip;
  final ValueChanged<int> onTapDay;
  const JourneyMapView({super.key, required this.trip, required this.onTapDay});

  static const _maxStops = 3;

  @override
  Widget build(BuildContext context) {
    final days = trip.days;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Rail(),
          Expanded(
            child: Column(
              // Without stretch, a day row's Stack sizes to its own (shorter)
              // content and Column centers it — the giveaway was short-route
              // days (usually the first/last) landing visibly indented next
              // to longer-route days that happened to span the full width.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  _DayRow(dayIndex: i, day: days[i], trip: trip, onTap: () => onTapDay(i)),
                  if (i < days.length - 1) const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Width of the rail column — shared with [_DayRow] so its dot lands exactly
/// on the line's center regardless of either value changing later.
const _railWidth = 18.0;
const _dotSize = 9.0;

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _railWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        // Center gives the painted line loose height constraints; without an
        // explicit height a plain Container here collapses to zero and never
        // draws — SizedBox.expand claims all the height Center offers.
        child: Center(
          child: SizedBox(
            width: 2,
            child: SizedBox.expand(child: CustomPaint(painter: _DottedRailPainter())),
          ),
        ),
      ),
    );
  }
}

class _DottedRailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accent.withValues(alpha: 0.4);
    const spacing = 7.0;
    final x = size.width / 2;
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawCircle(Offset(x, y), 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRailPainter oldDelegate) => false;
}

class _DayRow extends StatelessWidget {
  final int dayIndex;
  final DateTime day;
  final Trip trip;
  final VoidCallback onTap;
  const _DayRow({required this.dayIndex, required this.day, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = trip.itemsOn(day);
    final stops = items.take(JourneyMapView._maxStops).map((i) => i.title).toList();
    final extra = items.length - stops.length;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            // The rail's dotted line sits at the center of _railWidth; this
            // Stack starts right after that column, so centering the dot on
            // the line means offsetting back by half the rail plus half the
            // dot — not the old eyeballed "-18-4", which sat well past it.
            left: -(_railWidth / 2) - (_dotSize / 2),
            top: 3,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                boxShadow: [BoxShadow(color: AppColors.background, blurRadius: 0, spreadRadius: 3)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Day ${dayIndex + 1}', style: AppText.display(14.5)),
                const SizedBox(height: 2),
                Text(
                  '${dayWeekday(day).toUpperCase()} ${monthShort(day).toUpperCase()} ${dayNum(day)}',
                  style: AppText.label(8.5, color: AppColors.textMuted, tracking: 0.5),
                ),
                const SizedBox(height: 6),
                if (stops.isEmpty)
                  Text('Nothing planned', style: AppText.body(11.5, color: AppColors.textMuted))
                else
                  Text.rich(
                    TextSpan(
                      children: [
                        for (var i = 0; i < stops.length; i++) ...[
                          if (i > 0) TextSpan(text: '  →  ', style: AppText.body(11, color: AppColors.textMuted)),
                          TextSpan(text: stops[i], style: AppText.body(11.5, color: AppColors.textSecondary)),
                        ],
                        if (extra > 0)
                          TextSpan(text: '  +$extra', style: AppText.label(10, color: AppColors.textMuted)),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
