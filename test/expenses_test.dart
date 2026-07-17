import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plansync/controllers/trip_controller.dart';
import 'package:plansync/models/trip.dart';
import 'package:plansync/ui/trip/widgets/budget_summary.dart';

void main() {
  testWidgets('a prior expense added via the budget sheet counts toward spend', (tester) async {
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
      endDate: d.add(const Duration(days: 2)),
      budget: 1000,
      currency: 'USD',
      cover: TripCover.teal,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: BudgetBar(trip: trip)))));
    await tester.pumpAndSettle();

    // Open the budget details sheet, then the add-expense dialog.
    await tester.tap(find.byType(BudgetBar));
    await tester.pumpAndSettle();
    expect(find.text('EXTRA EXPENSES'), findsOneWidget);

    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    // Fill the dialog (label + amount) and confirm.
    await tester.enterText(find.byType(TextField).at(0), 'Park Hotel');
    await tester.enterText(find.byType(TextField).at(1), '612.50');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(trip.expenses.length, 1);
    expect(trip.expenses.first.label, 'Park Hotel');
    expect(trip.spent, 612.5);
    expect(find.text('Park Hotel'), findsOneWidget);
  });
}
