import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plansync/controllers/trip_controller.dart';
import 'package:plansync/models/category.dart';
import 'package:plansync/models/itinerary_item.dart';
import 'package:plansync/ui/shared/add_item_sheet.dart';

void main() {
  // Viewing a plan now lives in a read-only dialog; the sheet is create/edit
  // only. An existing plan opens directly in edit mode and saves + closes.
  testWidgets('existing plan opens in edit mode and saves changes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = TripController.instance;
    await c.load();
    for (final t in [...c.trips]) {
      await c.deleteTrip(t.id);
    }
    final d = DateTime(2026, 7, 1);
    final trip = await c.addTrip(
      name: 'T',
      destination: null,
      startDate: d,
      endDate: d.add(const Duration(days: 1)),
      budget: 0,
      currency: 'USD',
    );
    final item = ItineraryItem(id: 'x', title: 'Museum', category: PlanCategory.activity, day: d, cost: 10);
    trip.items.add(item);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => AddItemSheet.show(ctx, trip: trip, day: d, existing: item, startEditing: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Opens editable — no read-only "Plan Details" view, and a Save action.
    expect(find.text('Edit Plan'), findsOneWidget);
    expect(find.text('Plan Details'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    // Edit the title and save → persists and closes the sheet.
    await tester.enterText(find.byType(TextField).first, 'Museum Tour');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(item.title, 'Museum Tour');
    expect(find.text('Edit Plan'), findsNothing);
  });
}
