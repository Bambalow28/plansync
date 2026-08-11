import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../models/itinerary_item.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Trip Review layout: each day as its own card with a postmark-style day
/// stamp and a tight, timed list of that day's plans.
class PostcardDeckView extends StatelessWidget {
  final Trip trip;
  final ValueChanged<int> onTapDay;
  const PostcardDeckView({super.key, required this.trip, required this.onTapDay});

  @override
  Widget build(BuildContext context) {
    final days = trip.days;
    return Column(
      children: [
        for (var i = 0; i < days.length; i++) ...[
          _DayCard(dayIndex: i, day: days[i], trip: trip, onTap: () => onTapDay(i)),
          if (i < days.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  final int dayIndex;
  final DateTime day;
  final Trip trip;
  final VoidCallback onTap;
  const _DayCard({required this.dayIndex, required this.day, required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = trip.itemsOn(day);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day ${dayIndex + 1}', style: AppText.display(16)),
                      const SizedBox(height: 2),
                      Text(
                        '${dayWeekday(day)}, ${monthShort(day)} ${dayNum(day)}',
                        style: AppText.label(9, color: AppColors.textMuted, tracking: 0.8),
                      ),
                    ],
                  ),
                ),
                _DayStamp(dayIndex: dayIndex, day: day),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Nothing planned', style: AppText.body(12, color: AppColors.textMuted)),
              )
            else
              for (final item in items) _PlaceRow(item: item, day: day),
          ],
        ),
      ),
    );
  }
}

class _DayStamp extends StatelessWidget {
  final int dayIndex;
  final DateTime day;
  const _DayStamp({required this.dayIndex, required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5), width: 1.5, style: BorderStyle.solid),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${dayIndex + 1}', style: AppText.display(15)),
            Text(monthShort(day).toUpperCase(), style: AppText.label(6, color: AppColors.textMuted, tracking: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final ItineraryItem item;
  final DateTime day;
  const _PlaceRow({required this.item, required this.day});

  @override
  Widget build(BuildContext context) {
    final s = styleOf(item.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7)),
            child: Icon(s.icon, size: 13, color: s.color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13, weight: FontWeight.w500)),
          ),
          Text(item.displayStartLabel(day), style: AppText.label(10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
