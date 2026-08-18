import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../shared/create_choice_sheet.dart';
import '../shared/place_search_field.dart';
import '../trip/trip_detail_screen.dart';
import '../trip/trip_review_screen.dart';
import 'widgets/suggested_carousel.dart';
import 'widgets/trip_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _dismissibleCard(
    BuildContext context,
    Trip trip, {
    bool dimmed = false,
  }) {
    return Dismissible(
      key: ValueKey(trip.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDeleteTrip(context, trip),
      onDismissed: (_) => TripController.instance.deleteTrip(trip.id),
      child: TripCard(
        trip: trip,
        dimmed: dimmed,
        // Only past trips get the day-by-day Review summary; an ongoing or
        // upcoming trip opens straight into the usual full-itinerary view.
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => trip.isPast
                ? TripReviewScreen(tripId: trip.id)
                : TripDetailScreen(tripId: trip.id, showFullTopBar: true),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteTrip(BuildContext context, Trip trip) async {
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
            child: Text(
              'Cancel',
              style: AppText.body(14, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppText.body(14, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripController.instance;
    return Scaffold(
      floatingActionButton: _NewTripButton(
        onTap: () => CreateChoiceSheet.show(context),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final trips = controller.trips;
            final active = [
              for (final t in trips)
                if (!t.isPast) t,
            ];
            final past = [
              for (final t in trips)
                if (t.isPast) t,
            ];

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(trips: trips)),
                const SliverToBoxAdapter(child: SuggestedCarousel()),
                const SliverToBoxAdapter(child: SizedBox(height: 26)),
                if (trips.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyState())
                else ...[
                  // Every trip can be in the past, in which case this section
                  // (header included) drops out entirely.
                  if (active.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 20, 10),
                        child: Text(
                          'YOUR TRIPS',
                          style: AppText.label(11, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        past.isEmpty ? 120 : 8,
                      ),
                      sliver: SliverList.separated(
                        itemCount: active.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, i) => _EntranceFade(
                          index: i,
                          child: _dismissibleCard(context, active[i]),
                        ),
                      ),
                    ),
                  ],
                  if (past.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 20, 10),
                        child: Text(
                          'PAST TRIPS',
                          style: AppText.label(11, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      sliver: SliverList.separated(
                        itemCount: past.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, i) => _EntranceFade(
                          index: active.length + i,
                          child: _dismissibleCard(context, past[i], dimmed: true),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final List trips;
  const _Header({required this.trips});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = trips
        .where((t) => t.endDate.isAfter(DateTime.now()))
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        blurRadius: 16,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.travel_explore_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Plan',
                      style: AppText.label(
                        13,
                        color: AppColors.textSecondary,
                        tracking: 2,
                      ),
                    ),
                    TextSpan(
                      text: 'Sync',
                      style:
                          AppText.label(
                            13,
                            color: AppColors.accent,
                            tracking: 2,
                          ).copyWith(
                            shadows: [
                              Shadow(
                                color: AppColors.accent.withValues(alpha: 0.45),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(_greeting, style: AppText.label(12, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text('Your trips', style: AppText.display(34)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Text(
              trips.isEmpty
                  ? 'Plan your first adventure'
                  : '${trips.length} trip${trips.length == 1 ? '' : 's'} · $upcoming upcoming',
              key: ValueKey(trips.length),
              style: AppText.body(14, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          const _DestinationSearchBar(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// "Where to go?" field at the top of the home screen. Wraps the shared
/// [PlaceSearchField] (same offline city dataset and dropdown used in the trip
/// forms); picking a city opens the create flow with it pre-filled, then
/// clears so the bar is ready for the next search.
class _DestinationSearchBar extends StatefulWidget {
  const _DestinationSearchBar();

  @override
  State<_DestinationSearchBar> createState() => _DestinationSearchBarState();
}

class _DestinationSearchBarState extends State<_DestinationSearchBar> {
  // Bumped after each pick to remount the field with an empty value — the
  // field owns its own text controller, so this is how it gets reset.
  int _generation = 0;

  void _onSelected(Place? place) {
    if (place == null) return;
    setState(() => _generation++);
    CreateChoiceSheet.show(context, initialDestination: place);
  }

  @override
  Widget build(BuildContext context) {
    return PlaceSearchField(
      key: ValueKey(_generation),
      hint: 'Where to go?',
      onSelected: _onSelected,
    );
  }
}

/// One-shot fade-and-rise for a list item, staggered by [index] so the trips
/// arrive in sequence rather than all at once.
class _EntranceFade extends StatelessWidget {
  final int index;
  final Widget child;
  const _EntranceFade({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Later cards start later, but the stagger stops growing after a handful
      // so a long list doesn't leave the last card waiting seconds to appear.
      duration: Duration(milliseconds: 380 + 70 * (index.clamp(0, 5))),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Icon(
                Icons.luggage_rounded,
                size: 34,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text('No trips yet', style: AppText.display(22)),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create a trip,\nset a budget, and plan each day.',
              textAlign: TextAlign.center,
              style: AppText.body(14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTripButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewTripButton({required this.onTap});

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
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.black, size: 20),
            const SizedBox(width: 6),
            Text(
              'New Trip',
              style: AppText.body(
                15,
                color: Colors.black,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
