import 'package:flutter/material.dart';
import '../../models/place.dart';
import '../../theme/app_theme.dart';
import 'add_trip_sheet.dart';
import 'ai_create_trip_screen.dart';

/// Choice sheet shown before creating a trip: AI-drafted or manual.
class CreateChoiceSheet extends StatelessWidget {
  /// Pre-fills the destination when the flow was entered from a place the user
  /// already picked (home search bar, suggested-destination carousel).
  final Place? initialDestination;

  const CreateChoiceSheet({super.key, this.initialDestination});

  static Future<void> show(BuildContext context, {Place? initialDestination}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateChoiceSheet(initialDestination: initialDestination),
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
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _ChoiceCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Create with AI',
                subtitle: 'Let PlanSync draft your itinerary',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiCreateTripScreen(
                        initialDestination: initialDestination,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                icon: Icons.edit_note_rounded,
                title: 'Create Manual',
                subtitle: 'Build your trip step by step',
                onTap: () {
                  Navigator.pop(context);
                  AddTripSheet.show(context, initialDestination: initialDestination);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(16, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppText.body(13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
