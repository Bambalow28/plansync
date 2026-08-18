import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../shared/add_trip_sheet.dart';
import 'trip_detail_screen.dart';
import 'widgets/budget_summary.dart';
import 'widgets/postcard_deck_view.dart';
import 'widgets/trip_top_bar.dart';

/// The trip landing screen: a day-by-day postcard summary rather than the full
/// itinerary. Tapping a day drills into [TripDetailScreen] for that day's full
/// timeline.
class TripReviewScreen extends StatefulWidget {
  final String tripId;
  const TripReviewScreen({super.key, required this.tripId});

  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  void _openDay(Trip trip, int dayIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id, initialDayIndex: dayIndex)),
    );
  }

  Future<void> _confirmDelete(Trip trip) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Delete trip?', style: AppText.display(20)),
        content: Text(
          '“${trip.name}” and all its plans will be removed.',
          style: AppText.body(14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppText.body(14, color: AppColors.warning)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await TripController.instance.deleteTrip(trip.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TripController.instance,
      builder: (context, _) {
        final trip = TripController.instance.tripById(widget.tripId);
        if (trip == null) return const Scaffold(body: SizedBox.shrink());
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: TripTopBar(
                  trip: trip,
                  onEdit: () => AddTripSheet.show(context, existing: trip),
                  onDelete: () => _confirmDelete(trip),
                ),
              ),
              SliverToBoxAdapter(child: BudgetBar(trip: trip)),
              SliverToBoxAdapter(child: const SizedBox(height: 12)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
                sliver: SliverToBoxAdapter(
                  child: PostcardDeckView(
                    trip: trip,
                    onTapDay: (i) => _openDay(trip, i),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
