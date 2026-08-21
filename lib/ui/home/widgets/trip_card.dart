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
              gradient: AppColors.tripPhotoFallback,
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

/// Days until the trip starts — swapped for an "IN PROGRESS" label, the whole
/// badge breathing between its resting look and the app's accent color, once
/// the trip is actually running (a countdown to a trip already underway
/// would otherwise just read as 0).
class _DayBadge extends StatefulWidget {
  final int daysUntil;
  final bool ongoing;
  const _DayBadge({required this.daysUntil, required this.ongoing});

  @override
  State<_DayBadge> createState() => _DayBadgeState();
}

class _DayBadgeState extends State<_DayBadge> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.ongoing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _DayBadge old) {
    super.didUpdateWidget(old);
    if (widget.ongoing == old.ongoing) return;
    if (widget.ongoing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _restBackground = Color(0x52000000); // Colors.black @ 0.32
  static const _restBorder = Color(0x1AFFFFFF); // Colors.white @ 0.1

  @override
  Widget build(BuildContext context) {
    if (!widget.ongoing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _restBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _restBorder),
        ),
        child: Column(
          children: [
            Text('${widget.daysUntil}', style: AppText.display(19)),
            Text(
              'TO GO',
              style: AppText.label(8, color: AppColors.textMuted, tracking: 1.5),
            ),
          ],
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Color.lerp(_restBackground, AppColors.accent.withValues(alpha: 0.35), t),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color.lerp(_restBorder, AppColors.accent, t)!),
          ),
          child: Text('IN PROGRESS', style: AppText.label(10, tracking: 1.1)),
        );
      },
    );
  }
}
