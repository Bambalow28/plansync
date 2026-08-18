import 'package:flutter/material.dart';
import '../../services/advisor_workspace.dart';
import '../../theme/app_theme.dart';
import '../shared/destination_photo.dart';
import '../../models/trip.dart';

/// Managing the places an advisor has been, and which ones travellers see.
///
/// The switch is the whole point of the screen, so each row shows what it is
/// switching: the photo and the note as they will appear on the public
/// timeline. Hidden rows stay legible rather than being greyed into
/// unreadability — an advisor has to be able to reconsider them.
class AdvisorTravelsScreen extends StatelessWidget {
  const AdvisorTravelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = AdvisorWorkspace.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Travels', style: AppText.display(19)),
      ),
      body: ListenableBuilder(
        listenable: workspace,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              Text(
                '${workspace.shownPlaces.length} of ${workspace.places.length} appear on your public profile, newest first.',
                style: AppText.body(14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 22),
              for (final place in workspace.places) ...[
                _TravelRow(
                  place: place,
                  onToggle: (v) => workspace.togglePlace(place, v),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 6),
              const _AddPlaceButton(),
            ],
          );
        },
      ),
    );
  }
}

class _TravelRow extends StatelessWidget {
  final MyPlace place;
  final ValueChanged<bool> onToggle;
  const _TravelRow({required this.place, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: place.shown ? AppColors.accent.withValues(alpha: 0.28) : AppColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: DestinationPhoto(
              query: '${place.city} ${place.country} travel',
              gradient: tripCovers[TripCover.teal]!,
              dimmed: !place.shown,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.display(19),
                          ),
                        ),
                        Text(
                          '${place.year}',
                          style: AppText.label(10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    place.note,
                    style: AppText.body(13, color: AppColors.textSecondary).copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Switch(
                      value: place.shown,
                      activeThumbColor: Colors.black,
                      activeTrackColor: AppColors.accent,
                      onChanged: onToggle,
                    ),
                    Text(
                      place.shown ? 'SHOWN' : 'HIDDEN',
                      style: AppText.label(
                        8,
                        color: place.shown ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPlaceButton extends StatelessWidget {
  const _AddPlaceButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text(
            'Adding places comes with the real advisor backend.',
            style: AppText.body(13),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 17, color: AppColors.accent),
            const SizedBox(width: 7),
            Text(
              'Add a place',
              style: AppText.body(14, color: AppColors.accent, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Initials on a tinted field, shared by the advisor surfaces. No stock
/// headshots standing in for people.
class MonogramAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double radius;
  const MonogramAvatar({super.key, required this.name, this.size = 46, this.radius = 15});

  String get _initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.accentAlt.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Text(_initials, style: AppText.display(size * 0.37, color: AppColors.accent)),
    );
  }
}
