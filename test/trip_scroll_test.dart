import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plansync/controllers/trip_controller.dart';
import 'package:plansync/models/category.dart';
import 'package:plansync/models/itinerary_item.dart';
import 'package:plansync/models/trip.dart';
import 'package:plansync/ui/trip/trip_detail_screen.dart';
import 'package:plansync/ui/trip/widgets/budget_summary.dart';

void main() {
  testWidgets('budget bar scrolls away with the page (not pinned)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = TripController.instance;
    await c.load();
    for (final t in [...c.trips]) {
      await c.deleteTrip(t.id);
    }
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    final trip = await c.addTrip(
      name: 'Scroll Test',
      destination: null,
      startDate: d,
      endDate: d.add(const Duration(days: 2)),
      budget: 1000,
      currency: 'USD',
      cover: TripCover.teal,
    );
    for (var i = 0; i < 6; i++) {
      await c.addItem(
        trip.id,
        (id) => ItineraryItem(
          id: id,
          title: 'Item $i',
          category: PlanCategory.activity,
          day: d,
          start: DateTime(d.year, d.month, d.day, 8 + i),
          end: DateTime(d.year, d.month, d.day, 9 + i),
          cost: 10,
        ),
      );
    }

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: TripDetailScreen(tripId: trip.id)));
    await tester.pumpAndSettle();

    expect(find.byType(BudgetBar), findsOneWidget);
    final before = tester.getTopLeft(find.byType(BudgetBar)).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pump();

    // A pinned bar would stay at the same position and still be found. Ours
    // either scrolls off-screen or moves up — both prove it isn't pinned.
    final finder = find.byType(BudgetBar);
    if (finder.evaluate().isEmpty) {
      // Scrolled out of the viewport — definitively not pinned.
    } else {
      expect(tester.getTopLeft(finder).dy, lessThan(before),
          reason: 'budget bar should scroll up with the page, not stay pinned');
    }
  });
}
