import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plansync/models/category.dart';
import 'package:plansync/models/itinerary_item.dart';
import 'package:plansync/models/place.dart';
import 'package:plansync/ui/trip/widgets/timeline_view.dart';

void main() {
  // The day under test.
  final d = DateTime(2026, 7, 1);
  final yesterday = d.subtract(const Duration(days: 1));
  final tomorrow = d.add(const Duration(days: 1));
  DateTime at(DateTime day, int h, int m) => DateTime(day.year, day.month, day.day, h, m);

  final items = <ItineraryItem>[
    // Arrival flight: started yesterday, lands today 06:00 → should get an
    // ARRIVES end node with a spine from 12:00 AM down to 06:00.
    ItineraryItem(
      id: 'arr',
      title: 'Flight from NYC',
      category: PlanCategory.flight,
      location: const Place(city: 'Paris', country: 'France'),
      day: yesterday,
      start: at(yesterday, 23, 0),
      end: at(d, 6, 0),
    ),
    // Same-day container 09:00–17:00 with two nested items → ENDS end node.
    ItineraryItem(id: 'tour', title: 'City Walking Tour', category: PlanCategory.activity, day: d, start: at(d, 9, 0), end: at(d, 17, 0)),
    ItineraryItem(id: 'lunch', title: 'Lunch at Café', category: PlanCategory.food, day: d, start: at(d, 12, 0), end: at(d, 13, 0)),
    // Departing flight: leaves tonight, lands tomorrow → spine to END OF DAY,
    // no end node today.
    ItineraryItem(id: 'dep', title: 'Flight to Paris (CDG)', category: PlanCategory.flight, day: d, start: at(d, 23, 30), end: at(tomorrow, 6, 0)),
    ItineraryItem(id: 'lounge', title: 'Airport Lounge', category: PlanCategory.activity, day: d, start: at(d, 23, 40), end: at(d, 23, 50)),
  ];

  testWidgets('timeline renders bookends, journey end nodes, and nested items', (tester) async {
    // Tall viewport so the lazy ListView builds every row.
    tester.view.physicalSize = const Size(450, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TimelineView(items: items, currency: 'USD', day: d, onTapItem: (_) {}, onTapGroup: (_) {}),
        ),
      ),
    ));

    // Bookends.
    expect(find.text('START OF DAY'), findsOneWidget);
    expect(find.text('END OF DAY'), findsOneWidget);

    // Arrival flight produces an ARRIVES end node (the day-2 "show the end of
    // the journey" fix). The departing flight spans past today, so it has no
    // end node — ARRIVES appears exactly once.
    expect(find.text('ARRIVES'), findsOneWidget);

    // Every plan whose end doesn't line up with the next plan's start gets an
    // ENDS node — including nested/overlapping ones (Lunch inside the Tour,
    // Airport Lounge inside the departing flight's window), rendered as a
    // side label off the trunk's spine rather than a full trunk marker.
    expect(find.text('ENDS'), findsNWidgets(3)); // Tour, Lunch, Airport Lounge

    // Titles that own an end node appear twice (card + end-node label); the
    // departing flight has none since it spans past today's end.
    expect(find.text('Flight from NYC'), findsNWidgets(2)); // card + ARRIVES
    expect(find.text('City Walking Tour'), findsNWidgets(2)); // card + ENDS
    expect(find.text('Lunch at Café'), findsNWidgets(2)); // card + ENDS
    expect(find.text('Airport Lounge'), findsNWidgets(2)); // card + ENDS
    expect(find.text('Flight to Paris (CDG)'), findsOneWidget);

    // Day-2 arrival card shows the clamped range; departing shows "(Next day)".
    expect(find.text('12:00 AM – 6:00 AM'), findsOneWidget);
    expect(find.text('11:30 PM – 6:00 AM (Next day)'), findsOneWidget);

    // No RenderFlex overflow or layout exception occurred.
    expect(tester.takeException(), isNull);
  });

  testWidgets('plans ending at the same instant collapse into one tappable marker', (tester) async {
    tester.view.physicalSize = const Size(450, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Two unrelated plans that happen to end at the same time.
    final sameEnd = <ItineraryItem>[
      ItineraryItem(id: 'a', title: 'Museum Visit', category: PlanCategory.sightseeing, day: d, start: at(d, 10, 0), end: at(d, 12, 0)),
      ItineraryItem(id: 'b', title: 'Coffee Break', category: PlanCategory.food, day: d, start: at(d, 11, 0), end: at(d, 12, 0)),
    ];

    List<ItineraryItem>? tappedGroup;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TimelineView(
            items: sameEnd,
            currency: 'USD',
            day: d,
            onTapItem: (_) {},
            onTapGroup: (g) => tappedGroup = g,
          ),
        ),
      ),
    ));

    // One merged marker, not two separate ENDS rows.
    expect(find.text('2 PLANS END'), findsOneWidget);
    expect(find.text('ENDS'), findsNothing);

    await tester.tap(find.text('2 PLANS END'));
    await tester.pump();
    expect(tappedGroup, isNotNull);
    expect(tappedGroup!.map((i) => i.id), containsAll(['a', 'b']));

    expect(tester.takeException(), isNull);
  });

  group('fitDashes', () {
    // Invariants that must hold for any row height, or two abutting rail
    // segments will visually merge (touch) or leave an oversized gap at the
    // seam between rows — the two bugs this function exists to prevent.
    void checkInvariants(double h) {
      final spans = fitDashes(h);
      if (h <= dashSeamGap) {
        expect(spans, isEmpty, reason: 'h=$h too short for even the seam gap');
        return;
      }
      expect(spans, isNotEmpty, reason: 'h=$h');
      // First dash starts right at the node (distance 0).
      expect(spans.first.start, 0, reason: 'h=$h');
      // Every dash has non-negative length and stays within the piece.
      for (final s in spans) {
        expect(s.end, greaterThanOrEqualTo(s.start), reason: 'h=$h');
        expect(s.end, lessThanOrEqualTo(h), reason: 'h=$h');
      }
      // No overlaps, and no gap between consecutive dashes exceeds the target.
      for (var i = 1; i < spans.length; i++) {
        final gap = spans[i].start - spans[i - 1].end;
        expect(gap, greaterThanOrEqualTo(-1e-9), reason: 'overlap at h=$h');
        expect(gap, lessThanOrEqualTo(dashTargetGap + 1e-9), reason: 'oversized internal gap at h=$h');
      }
      // Exactly dashSeamGap of blank space is reserved at the far (seam) end.
      expect(h - spans.last.end, closeTo(dashSeamGap, 1e-9), reason: 'h=$h');
    }

    test('holds across a spread of row heights, including short ones', () {
      for (var h = 0.0; h <= 120; h += 0.5) {
        checkInvariants(h);
      }
    });
  });
}
