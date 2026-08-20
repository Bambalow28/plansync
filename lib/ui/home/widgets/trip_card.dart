import 'package:flutter/material.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../shared/destination_photo.dart';
import 'trip_stamp.dart';

/// A trip summary card, built on the same photo backdrop as the suggested-
/// destination carousel: the destination's own photograph when there's a
/// network and a key, the trip's gradient cover otherwise.
///
/// Reading order top to bottom: where it is, what it's called, when it runs,
/// and — when a budget is set — how the money is going. A countdown badge
/// sits top-right, opposite the place — days until the trip starts, for
/// active/upcoming trips only.
///
/// The whole card is the tap target for both active and past trips. An earlier
/// version put a small "View trip" button on past cards and made their body
/// inert; a full-bleed photo already reads as one object, so a competing
/// button inside it just shrank the target and split the affordance in two.
/// Past trips are instead marked by a desaturated photo and a small DONE
/// stamp in the badge's corner.
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  /// Past trips render desaturated so they read as archived.
  final bool dimmed;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.dimmed = false,
  });

  static const double _height = 210;

  @override
  Widget build(BuildContext context) {
    final baseColors = tripCovers[trip.cover]!;
    final colors = dimmed
        ? [
            for (final c in baseColors)
              Color.lerp(c, AppColors.surfaceLow, 0.78)!,
          ]
        : baseColors;

    final ongoing = !dimmed && tripIsOngoing(trip.startDate, trip.endDate);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: _height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: DestinationPhoto(
              query: trip.hasDestination
                  ? '${trip.destination!.city} ${trip.destination!.country} travel'
                  : '',
              gradient: colors,
              dimmed: dimmed,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _PlaceLine(trip: trip)),
                        const SizedBox(width: 12),
                        dimmed
                            ? DoneStamp(trip: trip, diameter: 46)
                            : _DayBadge(
                                daysUntil: trip.daysUntilStart,
                                ongoing: ongoing,
                              ),
                      ],
                    ),
                    const Spacer(),
                    if (trip.budget > 0) ...[
                      _BudgetProgress(trip: trip),
                      const SizedBox(height: 10),
                    ],
                    _Footer(trip: trip),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// City and country, above the trip's own name — the fact the photo is of.
class _PlaceLine extends StatelessWidget {
  final Trip trip;
  const _PlaceLine({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.place_rounded, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            trip.hasDestination
                ? trip.destinationLabel.toUpperCase()
                : 'NO DESTINATION',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(10, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Dates — the countdown lives on the day badge, top-right, so it isn't
/// repeated here.
class _DateLine extends StatelessWidget {
  final Trip trip;
  const _DateLine({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: 12,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            shortRange(trip.startDate, trip.endDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(12, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Just the budget progress bar — the spent/left figure moved into [_Footer],
/// alongside the trip name and dates.
class _BudgetProgress extends StatelessWidget {
  final Trip trip;
  const _BudgetProgress({required this.trip});

  @override
  Widget build(BuildContext context) {
    final spent = trip.spent;
    final ratio = (spent / trip.budget).clamp(0.0, 1.0);
    final over = spent > trip.budget;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 5,
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        valueColor: AlwaysStoppedAnimation(
          over ? AppColors.warning : AppColors.accent,
        ),
      ),
    );
  }
}

/// Trip name and dates, bottom-left. When a budget is set, the remaining (or
/// over) figure sits opposite them on the same line — the spot the "spent"
/// half of the budget line used to occupy.
class _Footer extends StatelessWidget {
  final Trip trip;
  const _Footer({required this.trip});

  @override
  Widget build(BuildContext context) {
    final nameAndDate = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trip.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.display(trip.budget > 0 ? 21 : 26),
        ),
        const SizedBox(height: 6),
        _DateLine(trip: trip),
      ],
    );
    if (trip.budget <= 0) return nameAndDate;

    final spent = trip.spent;
    final over = spent > trip.budget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: nameAndDate),
        const SizedBox(width: 10),
        Text(
          over
              ? '${money(spent - trip.budget, trip.currency)} over'
              : '${money(trip.remaining, trip.currency)} left',
          style: AppText.label(
            11,
            color: over ? AppColors.warning : AppColors.accent,
          ),
        ),
      ],
    );
  }
}

/// Days until the trip starts, with the live dot pinned inside its top-left
/// corner while the trip is actually running.
///
/// The badge's own padding (11 horizontal, 7 vertical) is moved onto the text
/// itself rather than the container, so that padding becomes genuinely empty
/// space in the Stack's top-left corner — real room for the dot to sit in
/// without growing the badge or overlapping the count/TO GO text.
class _DayBadge extends StatelessWidget {
  final int daysUntil;
  final bool ongoing;
  const _DayBadge({required this.daysUntil, required this.ongoing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Column(
              children: [
                Text('$daysUntil', style: AppText.display(19)),
                Text(
                  'TO GO',
                  style: AppText.label(
                    8,
                    color: AppColors.textMuted,
                    tracking: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (ongoing) const Positioned(left: 3, top: 3, child: _PulsingDot()),
        ],
      ),
    );
  }
}

/// A small "live" indicator for a trip in progress — a dot with an expanding,
/// fading halo, looping.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: 12,
          height: 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.5 + t * 1.5,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
