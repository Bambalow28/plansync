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

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Center(
        child: Container(
          width: 1,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.accent.withValues(alpha: 0.35), AppColors.accent.withValues(alpha: 0.08)],
            ),
          ),
        ),
      ),
    );
  }
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
            left: -18 - 4,
            top: 3,
            child: Container(
              width: 9,
              height: 9,
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
