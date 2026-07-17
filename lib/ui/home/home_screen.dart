import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../shared/add_trip_sheet.dart';
import '../trip/trip_detail_screen.dart';
import 'widgets/trip_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _dismissibleCard(BuildContext context, Trip trip, {bool dimmed = false}) {
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
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
            child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppText.body(14, color: AppColors.warning)),
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
        onTap: () => AddTripSheet.show(context),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final trips = controller.trips;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            bool isPast(t) => DateTime(t.endDate.year, t.endDate.month, t.endDate.day).isBefore(today);
            final active = [for (final t in trips) if (!isPast(t)) t];
            final past = [for (final t in trips) if (isPast(t)) t];

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(trips: trips)),
                if (trips.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, past.isEmpty ? 120 : 8),
                    sliver: SliverList.separated(
                      itemCount: active.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, i) => _dismissibleCard(context, active[i]),
                    ),
                  ),
                  if (past.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 20, 10),
                        child: Text('PAST TRIPS', style: AppText.label(11, color: AppColors.textMuted)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      sliver: SliverList.separated(
                        itemCount: past.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, i) => _dismissibleCard(context, past[i], dimmed: true),
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
        ],
      ),
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
