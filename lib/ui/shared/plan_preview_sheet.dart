import 'package:flutter/material.dart';
import '../../data/suggested_places.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'add_trip_sheet.dart';

/// Informational sheet shown before starting a trending plan: how many days
/// it covers, where, and roughly what it costs, with a button that carries
/// those defaults into trip creation.
class PlanPreviewSheet extends StatelessWidget {
  final SuggestedPlace place;
  const PlanPreviewSheet({super.key, required this.place});

  static Future<void> show(BuildContext context, SuggestedPlace place) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlanPreviewSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('${place.city}, ${place.country}', style: AppText.display(22)),
              const SizedBox(height: 4),
              Text(
                place.tagline,
                style: AppText.body(13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _Stat(label: 'Length', value: '${place.planDays} days'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(label: 'Area', value: place.country),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(label: 'Budget', value: money(place.planBudget, 'USD')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  AddTripSheet.show(context, planSource: place);
                },
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Start with this plan',
                    style: AppText.body(16, color: Colors.black, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.label(9, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(14, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
