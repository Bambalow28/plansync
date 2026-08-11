import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/trip.dart';
import '../../services/review_view_service.dart';
import '../../theme/app_theme.dart';
import '../shared/add_trip_sheet.dart';
import 'trip_detail_screen.dart';
import 'widgets/budget_summary.dart';
import 'widgets/journey_map_view.dart';
import 'widgets/postcard_deck_view.dart';
import 'widgets/trip_top_bar.dart';

/// The trip landing screen: a day-by-day summary (Postcard Deck or Journey
/// Map, the user's choice) rather than the full itinerary. Tapping a day
/// drills into [TripDetailScreen] for that day's full timeline.
class TripReviewScreen extends StatefulWidget {
  final String tripId;
  const TripReviewScreen({super.key, required this.tripId});

  @override
  State<TripReviewScreen> createState() => _TripReviewScreenState();
}

class _TripReviewScreenState extends State<TripReviewScreen> {
  ReviewView _view = ReviewView.postcard;

  @override
  void initState() {
    super.initState();
    ReviewViewService.instance.getView().then((v) {
      if (mounted) setState(() => _view = v);
    });
  }

  void _setView(ReviewView view) {
    if (view == _view) return;
    setState(() => _view = view);
    ReviewViewService.instance.setView(view);
  }

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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: _ViewSwitch(view: _view, onChanged: _setView),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 32 + bottomInset),
                sliver: SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _view == ReviewView.postcard
                        ? PostcardDeckView(
                            key: const ValueKey('postcard'),
                            trip: trip,
                            onTapDay: (i) => _openDay(trip, i),
                          )
                        : JourneyMapView(
                            key: const ValueKey('map'),
                            trip: trip,
                            onTapDay: (i) => _openDay(trip, i),
                          ),
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

class _ViewSwitch extends StatelessWidget {
  final ReviewView view;
  final ValueChanged<ReviewView> onChanged;
  const _ViewSwitch({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(label: 'Postcard', selected: view == ReviewView.postcard, onTap: () => onChanged(ReviewView.postcard)),
          _Segment(label: 'Map', selected: view == ReviewView.map, onTap: () => onChanged(ReviewView.map)),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppText.label(11, color: selected ? Colors.black : AppColors.textSecondary, tracking: 0.4).copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
