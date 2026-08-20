import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../services/advisor_workspace.dart';
import '../../services/auth_service.dart';
import '../../services/unsplash_service.dart';
import '../../theme/app_theme.dart';
import '../advisor/advisor_dashboard_screen.dart';
import '../advisor/apply_screen.dart';
import '../auth/sign_in_screen.dart';
import '../shared/create_choice_sheet.dart';
import '../shared/entrance_fade.dart';
import '../shared/place_search_field.dart';
import '../trip/trip_detail_screen.dart';
import '../trip/trip_review_screen.dart';
import 'widgets/suggested_carousel.dart';
import 'widgets/trip_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // The user's own trips get their photos resolved first — ahead of the
    // carousel's suggestions, which are the more expendable of the two if the
    // hourly Unsplash budget runs short.
    _prefetchTripPhotos();
  }

  Future<void> _prefetchTripPhotos() async {
    if (!UnsplashService.instance.isConfigured) return;
    for (final trip in TripController.instance.trips) {
      final destination = trip.destination;
      if (destination == null) continue;
      final url = await UnsplashService.instance
          .photoUrl('${destination.city} ${destination.country} travel');
      if (!mounted || url == null) continue;
      unawaited(precacheImage(CachedNetworkImageProvider(url), context));
    }
  }

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
                const SliverToBoxAdapter(child: _TopBar()),
                const SliverToBoxAdapter(child: SuggestedCarousel()),
                // Separates discovery above from the user's own trips below.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                    child: Divider(height: 1, thickness: 1, color: AppColors.hairline),
                  ),
                ),
                SliverToBoxAdapter(child: _GreetingBlock(trips: trips)),
                if (trips.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyState())
                else ...[
                  // Every trip can be in the past, in which case this section
                  // drops out entirely.
                  if (active.isNotEmpty) ...[
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
                        itemBuilder: (context, i) => EntranceFade(
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
                        itemBuilder: (context, i) => EntranceFade(
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

/// Brand row plus the "Where to go?" field — the discovery half of the screen,
/// which sits above the suggestions carousel.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
              const Spacer(),
              const _AdvisorButton(),
            ],
          ),
          const SizedBox(height: 22),
          const _DestinationSearchBar(),
        ],
      ),
    );
  }
}

/// The one control in the wordmark row, carrying whichever of the three
/// advisor states applies. It is deliberately one slot rather than a permanent
/// extra button: for most people this is an invitation they will tap once and
/// never see again, and for an advisor it becomes the way into their work.
class _AdvisorButton extends StatelessWidget {
  const _AdvisorButton();

  @override
  Widget build(BuildContext context) {
    final workspace = AdvisorWorkspace.instance;
    return ListenableBuilder(
      listenable: workspace,
      builder: (context, _) {
        final (label, icon, accent) = switch (workspace.status) {
          AdvisorStatus.none => ('Apply', Icons.workspace_premium_outlined, false),
          AdvisorStatus.pending => ('In review', Icons.hourglass_top_rounded, false),
          AdvisorStatus.approved => ('Advisor', Icons.workspace_premium_rounded, true),
        };
        final pending = workspace.status == AdvisorStatus.approved
            ? workspace.pendingRequestCount
            : 0;

        return GestureDetector(
          onTap: () async {
            if (AuthService.instance.currentUser == null) {
              final signedIn = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
              if (signedIn != true || !context.mounted) return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => workspace.status == AdvisorStatus.approved
                    ? const AdvisorDashboardScreen()
                    : const ApplyScreen(),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent
                      ? AppColors.accent.withValues(alpha: 0.14)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: accent
                        ? AppColors.accent.withValues(alpha: 0.45)
                        : AppColors.hairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 13,
                      color: accent ? AppColors.accent : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppText.label(
                        10,
                        color: accent ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Unanswered requests are the one thing here worth interrupting
              // the home screen for.
              if (pending > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                    child: Text(
                      '$pending',
                      style: AppText.label(8, color: Colors.white, tracking: 0),
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

/// Greeting and trip count — the "your stuff" half, below the carousel.
class _GreetingBlock extends StatelessWidget {
  final List<Trip> trips;
  const _GreetingBlock({required this.trips});

  @override
  Widget build(BuildContext context) {
    final upcoming = trips.where((t) => t.endDate.isAfter(DateTime.now())).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
