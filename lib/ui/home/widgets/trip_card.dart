import 'package:flutter/material.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../shared/destination_photo.dart';

/// A trip summary card, built on the same photo backdrop as the suggested-
/// destination carousel: the destination's own photograph when there's a
/// network and a key, the trip's gradient cover otherwise.
///
/// Reading order top to bottom: where it is, what it's called, when it runs,
/// and — when a budget is set — how the money is going. The day count sits
/// top-right, opposite the place.
///
/// The whole card is the tap target for both active and past trips. An earlier
/// version put a small "View trip" button on past cards and made their body
/// inert; a full-bleed photo already reads as one object, so a competing
/// button inside it just shrank the target and split the affordance in two.
/// Past trips are instead marked by a desaturated photo and a PAST chip.
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
        ? [for (final c in baseColors) Color.lerp(c, AppColors.surfaceLow, 0.78)!]
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
                        _DayBadge(count: trip.dayCount, ongoing: ongoing),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(26),
                    ),
                    const SizedBox(height: 6),
                    _DateLine(trip: trip, ongoing: ongoing, dimmed: dimmed),
                    if (trip.budget > 0) ...[
                      const SizedBox(height: 12),
                      _BudgetBar(trip: trip),
                    ],
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

/// Dates, plus the countdown (and live dot) while the trip still lies ahead.
class _DateLine extends StatelessWidget {
  final Trip trip;
  final bool ongoing;
  final bool dimmed;
  const _DateLine({required this.trip, required this.ongoing, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            shortRange(trip.startDate, trip.endDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label(12, color: AppColors.textSecondary),
          ),
        ),
        // A finished trip has no countdown left to run.
        if (!dimmed) ...[
          const Spacer(),
          Text(
            tripCountdownLabel(trip.startDate, trip.endDate),
            style: AppText.label(12, color: ongoing ? AppColors.accent : AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Budget progress with the spent/left figures on the same line as the bar's
/// meaning, kept to one row so the photo still has room to breathe.
class _BudgetBar extends StatelessWidget {
  final Trip trip;
  const _BudgetBar({required this.trip});

  @override
  Widget build(BuildContext context) {
    final spent = trip.spent;
    final ratio = (spent / trip.budget).clamp(0.0, 1.0);
    final over = spent > trip.budget;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            valueColor: AlwaysStoppedAnimation(
              over ? AppColors.warning : AppColors.accent,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              '${money(spent, trip.currency)} spent',
              style: AppText.label(10, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Text(
              over
                  ? '${money(spent - trip.budget, trip.currency)} over'
                  : '${money(trip.remaining, trip.currency)} left',
              style: AppText.label(10, color: over ? AppColors.warning : AppColors.accent),
            ),
          ],
        ),
      ],
    );
  }
}

/// Day count, with the live dot pinned to its top-left corner while the trip
/// is actually running.
class _DayBadge extends StatelessWidget {
  final int count;
  final bool ongoing;
  const _DayBadge({required this.count, required this.ongoing});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text('$count', style: AppText.display(19)),
          Text(
            'DAYS',
            style: AppText.label(8, color: AppColors.textMuted, tracking: 1.5),
          ),
        ],
      ),
    );
    if (!ongoing) return badge;
    // Clipping is off by default on Stack, so the dot can sit proud of the
    // badge's corner rather than being trimmed by it.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        const Positioned(left: -5, top: -5, child: _PulsingDot()),
      ],
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

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
              ),
            ],
          ),
        );
      },
    );
  }
}
