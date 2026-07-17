import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/trip_controller.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../services/itinerary_share.dart';
import '../../services/trip_link.dart';
import '../shared/add_item_sheet.dart';
import '../shared/add_trip_sheet.dart';
import 'widgets/budget_summary.dart';
import 'widgets/day_selector.dart';
import 'widgets/plan_details_dialog.dart';
import 'widgets/timeline_view.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

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
              _TopBar(
                trip: trip,
                onEdit: () => AddTripSheet.show(context, existing: trip),
                onDelete: () => _confirmDelete(trip),
              ),
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

class _TopBar extends StatelessWidget {
  final Trip trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TopBar({required this.trip, required this.onEdit, required this.onDelete});

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
    final flag = trip.destination != null ? flagEmoji(trip.destination!.countryCode) : '';
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
                if (flag.isNotEmpty) ...[
                  Text(flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                ] else ...[
                  Icon(Icons.place_rounded, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                ],
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
