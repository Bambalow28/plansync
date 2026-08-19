import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/trip.dart';
import '../../../services/itinerary_share.dart';
import '../../../services/trip_link.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Full trip header — back, name, share/edit/delete, destination + dates.
/// The landing-level chrome for a trip: [TripReviewScreen] owns this; the
/// per-day [TripDetailScreen] one level in keeps a lighter bar of its own.
class TripTopBar extends StatelessWidget {
  final Trip trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const TripTopBar({super.key, required this.trip, required this.onEdit, required this.onDelete});

  Future<void> _shareItinerary(BuildContext context) async {
    // Anchor the share sheet (needed on iPad). Fall back to copying the text if
    // the share sheet can't be presented for any reason.
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await ItineraryShare.sharePdf(trip, sharePositionOrigin: origin);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: ItineraryShare.buildText(trip)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Itinerary copied to clipboard')),
        );
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    // A self-contained link that carries the whole itinerary — no server. It
    // looks long/opaque because the trip data is packed inside it; opening it
    // on a device with PlanSync installed loads the itinerary.
    await Clipboard.setData(ClipboardData(text: TripLink.encode(trip).toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied. Tapping it in PlanSync opens this itinerary — paste it into a TravelSync post.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = tripCovers[trip.cover]!;
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, topInset + 6, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.first.withValues(alpha: 0.6), AppColors.background],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              // Trip title beside the back button, ellipsized if long.
              Expanded(
                child: Text(
                  trip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(22),
                ),
              ),
              PopupMenuButton<int>(
                icon: Icon(Icons.ios_share_rounded, color: AppColors.textSecondary),
                color: AppColors.surfaceHigh,
                onSelected: (v) {
                  if (v == 0) {
                    _shareItinerary(context);
                  } else {
                    _copyLink(context);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 0, child: Text('Share itinerary', style: AppText.body(14))),
                  PopupMenuItem(value: 1, child: Text('Copy trip link', style: AppText.body(14))),
                ],
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: AppColors.accent),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.warning),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 12, 0),
            child: Row(
              children: [
                Icon(Icons.place_rounded, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    trip.hasDestination ? trip.destinationLabel : 'No destination selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(13, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Text(shortRange(trip.startDate, trip.endDate), style: AppText.label(11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
