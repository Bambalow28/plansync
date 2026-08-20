import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../models/itinerary_item.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../home/widgets/trip_stamp.dart';
import '../../shared/entrance_fade.dart';

/// Trip Review layout: each day as its own card with a postmark-style day
/// stamp and a tight, timed list of that day's plans. Styled like a stack of
/// postcards from the trip — a perforated tear edge up top, a postmark in
/// the corner, and a dotted itinerary manifest, all settling into place with
/// a staggered entrance.
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
          EntranceFade(
            index: i,
            child: _DayCard(dayIndex: i, day: days[i], trip: trip, onTap: () => onTapDay(i)),
          ),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          gradient: AppColors.surfaceGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PerforationRow(),
            const SizedBox(height: 10),
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
                _DayStamp(dayIndex: dayIndex, day: day, trip: trip),
              ],
            ),
            const _FoldLine(),
            const SizedBox(height: 4),
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

/// A row of small tick marks along the top edge, like a torn perforation on
/// a postcard stub.
class _PerforationRow extends StatelessWidget {
  const _PerforationRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 7.0;
          final count = (constraints.maxWidth / gap).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < count; i++)
                Container(width: 2, height: 2, color: AppColors.hairline),
            ],
          );
        },
      ),
    );
  }
}

/// A dashed rule under the day header, like the fold on a postcard.
class _FoldLine extends StatelessWidget {
  const _FoldLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const dash = 4.0, gap = 3.0;
            final count = (constraints.maxWidth / (dash + gap)).floor();
            return Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  Container(width: dash, height: 1, color: AppColors.hairline),
                  if (i < count - 1) const SizedBox(width: gap),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The day's postmark — arced "DAY N" over the trip's destination country,
/// with the calendar date centered underneath. Presses into place a beat
/// after the card settles, like a rubber stamp.
class _DayStamp extends StatelessWidget {
  final int dayIndex;
  final DateTime day;
  final Trip trip;
  const _DayStamp({required this.dayIndex, required this.day, required this.trip});

  @override
  Widget build(BuildContext context) {
    final country = (trip.destination?.country.trim().isNotEmpty ?? false)
        ? trip.destination!.country.toUpperCase()
        : 'PLANSYNC';
    final stamp = PostmarkStamp(
      topText: 'DAY ${dayIndex + 1}',
      bottomText: country,
      centerText: '${dayWeekday(day)} ${monthShort(day)} ${dayNum(day)}'.toUpperCase(),
      seed: trip.id.hashCode ^ dayIndex,
      diameter: 48,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 70 * (dayIndex.clamp(0, 5))),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
      ),
      child: stamp,
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
          Flexible(
            child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13, weight: FontWeight.w500)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '.' * 200,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: AppText.label(11, color: AppColors.hairline, tracking: 0),
            ),
          ),
          const SizedBox(width: 6),
          Text(item.displayStartLabel(day), style: AppText.label(10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
