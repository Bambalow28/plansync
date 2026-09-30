import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../shared/add_item_sheet.dart';
import '../shared/add_trip_sheet.dart';
import 'widgets/budget_summary.dart';
import 'widgets/day_selector.dart';
import 'widgets/plan_details_dialog.dart';
import 'widgets/timeline_view.dart';
import 'widgets/trip_top_bar.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  /// Which day to open on. Defaults to today (if the trip is in progress)
  /// when omitted — set by [TripReviewScreen] when drilling into a specific
  /// day from the trip-level summary.
  final int? initialDayIndex;

  /// True when this screen is the trip's landing page (an ongoing or
  /// upcoming trip, opened directly from Home) rather than a drill-in from
  /// [TripReviewScreen] — only past trips get the Review summary, so a
  /// current trip needs its own edit/share/delete affordances here instead
  /// of one tap back.
  final bool showFullTopBar;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialDayIndex,
    this.showFullTopBar = false,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  int _dayIndex = 0;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDayIndex != null) {
      _dayIndex = widget.initialDayIndex!;
      return;
    }
    // Default to today if the trip is in progress.
    final trip = TripController.instance.tripById(widget.tripId);
    if (trip != null) {
      final today = DateTime.now();
      final idx = trip.days.indexWhere(
        (d) => d.year == today.year && d.month == today.month && d.day == today.day,
      );
      if (idx >= 0) _dayIndex = idx;
    }
  }

  void _goToDay(int i, int dayCount) {
    final clamped = i.clamp(0, dayCount - 1);
    if (clamped != _dayIndex) {
      setState(() => _dayIndex = clamped);
      // Switching days resets the page to the top of the timeline.
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
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

        final days = trip.days;
        if (_dayIndex >= days.length) _dayIndex = days.length - 1;
        final counts = days.map((d) => trip.itemsOn(d).length).toList();
        final selectedDay = days[_dayIndex];
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          floatingActionButton: _AddPlanButton(
            onTap: () => AddItemSheet.show(context, trip: trip, day: selectedDay),
          ),
          body: Column(
            children: [
              if (widget.showFullTopBar)
                TripTopBar(
                  trip: trip,
                  onEdit: () => AddTripSheet.show(context, existing: trip),
                  onDelete: () => _confirmDelete(trip),
                )
              else
                _DayTopBar(tripName: trip.name),
              // The whole page below the top bar scrolls together; a horizontal
              // swipe moves to the previous/next day.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -250) _goToDay(_dayIndex + 1, days.length);
                    if (v > 250) _goToDay(_dayIndex - 1, days.length);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(child: BudgetBar(trip: trip)),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: DaySelector(
                          days: days,
                          selectedIndex: _dayIndex,
                          counts: counts,
                          onSelect: (i) => _goToDay(i, days.length),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (trip.itemsOn(selectedDay).isEmpty)
                        // Center the empty state in the space below the day strip.
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 80 + bottomInset),
                            child: const Center(child: TimelineEmpty()),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: TimelineView(
                            items: trip.itemsOn(selectedDay),
                            currency: trip.currency,
                            day: selectedDay,
                            onTapItem: (item) => PlanDetailsDialog.show(
                              context,
                              trip: trip,
                              day: selectedDay,
                              item: item,
                            ),
                            onTapGroup: (items) => PlanGroupDialog.show(
                              context,
                              trip: trip,
                              day: selectedDay,
                              items: items,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: 120 + bottomInset)),
                      ],
                    ],
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

/// Lighter bar for the per-day drill-in: just back + trip name. Share, edit,
/// and delete live one tap back, on [TripReviewScreen]'s [TripTopBar].
class _DayTopBar extends StatelessWidget {
  final String tripName;
  const _DayTopBar({required this.tripName});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topInset + 6, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              tripName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(19),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPlanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPlanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 6),
            Text('Add Plan', style: AppText.body(15, color: Colors.black, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
