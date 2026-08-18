import 'package:flutter/material.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../shared/destination_photo.dart';

/// A trip summary card: gradient cover, name + destination, date range, day
/// count, and a budget progress bar.
class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  /// Past trips render dimmed/desaturated but still open on tap.
  final bool dimmed;
  const TripCard({super.key, required this.trip, required this.onTap, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final baseColors = tripCovers[trip.cover]!;
    // Past trips are heavily desaturated so they read as archived.
    final colors = dimmed
        ? [for (final c in baseColors) Color.lerp(c, AppColors.surfaceLow, 0.78)!]
        : baseColors;
    final spent = trip.spent;
    final hasBudget = trip.budget > 0;
    final ratio = hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && spent > trip.budget;
    final flag = trip.destination != null ? flagEmoji(trip.destination!.countryCode) : '';

    // The card's informational content (everything except the View-trip button).
    final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.display(24),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (flag.isNotEmpty) ...[
                              Text(flag, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                            ] else ...[
                              Icon(
                                Icons.place_rounded,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                trip.hasDestination
                                    ? trip.destinationLabel
                                    : 'No destination selected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(
                                  13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _DayBadge(count: trip.dayCount),
                ],
              ),
              // Active trips show the date range + countdown here. Past trips
              // move the dates down beside the View-trip button (no "Ended").
              if (!dimmed) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shortRange(trip.startDate, trip.endDate),
                      style: AppText.label(12, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    if (tripIsOngoing(trip.startDate, trip.endDate)) ...[
                      const _PulsingDot(),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      tripCountdownLabel(trip.startDate, trip.endDate),
                      style: AppText.label(12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              if (hasBudget) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(
                      over ? AppColors.warning : AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${money(spent, trip.currency)} spent',
                      style: AppText.label(11, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
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
                ),
              ],
            ],
          );

    if (!dimmed) {
      return GestureDetector(onTap: onTap, child: _shell(colors, info));
    }
    // Past trip: the body is dimmed and NOT tappable; only the subtle
    // "View trip" button (bottom-right) opens the trip.
    return _shell(
      colors,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(opacity: 0.45, child: info),
          const SizedBox(height: 16),
          // Dates aligned on the same row as the View-trip button.
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                shortRange(trip.startDate, trip.endDate),
                style: AppText.label(12, color: AppColors.textSecondary),
              ),
              const Spacer(),
              _ViewTripButton(onTap: onTap),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shell(List<Color> colors, Widget child) {
    // A trip with a real destination upgrades to a photo of it when there's a
    // network and a configured key; otherwise this is exactly the gradient
    // card it has always been.
    final query = trip.hasDestination
        ? '${trip.destination!.city} ${trip.destination!.country} travel'
        : '';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DestinationPhoto(
        query: query,
        gradient: colors,
        dimmed: dimmed,
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}

/// "View trip" action for a dimmed past-trip card. Accent-tinted so it clearly
/// reads as pressable, but soft enough not to compete with the bright "New
/// Trip" call-to-action.
class _ViewTripButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewTripButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View trip', style: AppText.body(13, color: AppColors.accent, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final int count;
  const _DayBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text('$count', style: AppText.display(20)),
          Text(
            'DAYS',
            style: AppText.label(8, color: AppColors.textMuted, tracking: 1.5),
          ),
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
