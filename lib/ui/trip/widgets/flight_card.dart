import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../models/itinerary_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// A Flighty-style boarding-pass view of a flight plan: big airport codes with
/// a plane tracing the route, duration in the middle, and departure/arrival
/// times. Used in the read-only plan view when [item.isFlight].
class FlightCard extends StatelessWidget {
  final ItineraryItem item;
  final DateTime day;

  /// When true (device offline), show a notice that live data may be stale.
  final bool offline;
  const FlightCard({super.key, required this.item, required this.day, this.offline = false});

  Color get _accent => styleOf(PlanCategory.flight).color;

  String _bigCode(String? code, String? cityLabel) {
    final c = code?.trim();
    if (c != null && c.isNotEmpty) return c.toUpperCase();
    final city = cityLabel?.split(',').first.trim() ?? '';
    return city.isNotEmpty ? city : '—';
  }

  String? _durationLabel() {
    if (item.start == null || item.end == null) return null;
    final d = item.end!.difference(item.start!);
    if (d.inMinutes <= 0) return null;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final depTime = item.start != null ? timeLabel(item.startMinutes!) : '—';
    final arrTime = item.end != null ? timeLabel(item.endMinutes!) : '—';
    final dur = _durationLabel();
    final dateLabel = fullDate(item.start ?? day);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: airline name (if known) + flight code chip.
          Row(
            children: [
              Icon(Icons.flight_rounded, size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (item.airlineName?.trim().isNotEmpty ?? false)
                      ? item.airlineName!.trim()
                      : ((item.flightCode?.trim().isNotEmpty ?? false)
                          ? item.flightCode!.trim().toUpperCase()
                          : 'Flight'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(20, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (item.flightCode?.trim().isNotEmpty ?? false)
                      ? item.flightCode!.trim().toUpperCase()
                      : 'SCHEDULED',
                  style: AppText.label(9, color: _accent, tracking: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Route: FROM  ✈ duration  TO
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _endpoint(
                code: _bigCode(item.departureCode, item.location?.label),
                city: item.location?.label,
                time: depTime,
                align: CrossAxisAlignment.start,
              ),
              Expanded(child: _routeLine(dur)),
              _endpoint(
                code: _bigCode(item.arrivalCode, item.arrivalLocation?.label),
                city: item.arrivalLocation?.label,
                time: arrTime,
                align: CrossAxisAlignment.end,
                nextDay: item.spansDays,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(dateLabel, style: AppText.label(11, color: AppColors.textSecondary)),
            ],
          ),
          if (offline) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You're offline — connect for live flight data.",
                      style: AppText.label(10, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _endpoint({
    required String code,
    required String? city,
    required String time,
    required CrossAxisAlignment align,
    bool nextDay = false,
  }) {
    final textAlign = align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(code, style: AppText.display(30, color: Colors.white), maxLines: 1),
        if (city != null && city.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          SizedBox(
            width: 96,
            child: Text(
              city,
              textAlign: textAlign,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(12, color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(time, style: AppText.label(13, color: Colors.white, tracking: 0.2)),
            if (nextDay)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text('+1', style: AppText.label(9, color: _accent)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _routeLine(String? duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          const SizedBox(height: 6),
          if (duration != null)
            Text(duration, style: AppText.label(10, color: AppColors.textMuted))
          else
            const SizedBox(height: 12),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Container(height: 1.5, color: _accent.withValues(alpha: 0.4))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.rotate(
                  angle: math.pi / 2,
                  child: Icon(Icons.flight_rounded, size: 18, color: _accent),
                ),
              ),
              Expanded(child: Container(height: 1.5, color: _accent.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }
}
