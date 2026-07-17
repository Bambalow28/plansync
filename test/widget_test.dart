import 'package:flutter_test/flutter_test.dart';

import 'package:plansync/models/trip.dart';
import 'package:plansync/models/itinerary_item.dart';
import 'package:plansync/models/category.dart';
import 'package:plansync/models/place.dart';

void main() {
  group('Trip', () {
    Trip sample() => Trip(
          id: 't1',
          name: 'Japan',
          destination: const Place(city: 'Tokyo', country: 'Japan'),
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 5),
          budget: 1000,
          currency: 'USD',
        );

    test('dayCount is inclusive', () {
      expect(sample().dayCount, 5);
      expect(sample().days.length, 5);
    });

    test('spent and remaining track item costs', () {
      final trip = sample();
      trip.items.add(ItineraryItem(
        id: 'i1',
        title: 'Hotel',
        category: PlanCategory.lodging,
        day: DateTime(2026, 6, 1),
        cost: 300,
      ));
      trip.items.add(ItineraryItem(
        id: 'i2',
        title: 'Dinner',
        category: PlanCategory.food,
        day: DateTime(2026, 6, 1),
        cost: 50,
      ));
      expect(trip.spent, 350);
      expect(trip.remaining, 650);
    });

    test('itemsOn filters and sorts by start time', () {
      final trip = sample();
      trip.items.addAll([
        ItineraryItem(id: 'a', title: 'Late', day: DateTime(2026, 6, 1), start: DateTime(2026, 6, 1, 10)),
        ItineraryItem(id: 'b', title: 'Early', day: DateTime(2026, 6, 1), start: DateTime(2026, 6, 1, 8)),
        ItineraryItem(id: 'c', title: 'Other day', day: DateTime(2026, 6, 2), start: DateTime(2026, 6, 2, 1)),
      ]);
      final items = trip.itemsOn(DateTime(2026, 6, 1));
      expect(items.map((i) => i.id).toList(), ['b', 'a']);
    });

    test('overnight item spans days', () {
      final flight = ItineraryItem(
        id: 'f',
        title: 'Red-eye',
        category: PlanCategory.flight,
        day: DateTime(2026, 6, 1),
        start: DateTime(2026, 6, 1, 23),
        end: DateTime(2026, 6, 2, 6),
      );
      expect(flight.spansDays, isTrue);
      expect(flight.isStartDay(DateTime(2026, 6, 1)), isTrue);
      expect(flight.isEndDay(DateTime(2026, 6, 2)), isTrue);
    });

    test('round-trips through JSON', () {
      final trip = sample()
        ..items.add(ItineraryItem(
          id: 'i1',
          title: 'Temple',
          location: const Place(city: 'Kyoto', country: 'Japan'),
          category: PlanCategory.sightseeing,
          day: DateTime(2026, 6, 2),
          start: DateTime(2026, 6, 2, 9),
          cost: 12.5,
        ));
      final restored = Trip.fromJson(trip.toJson());
      expect(restored.name, 'Japan');
      expect(restored.destination?.city, 'Tokyo');
      expect(restored.items.length, 1);
      expect(restored.items.first.category, PlanCategory.sightseeing);
      expect(restored.items.first.location?.label, 'Kyoto, Japan');
      expect(restored.items.first.start, DateTime(2026, 6, 2, 9));
      expect(restored.spent, 12.5);
    });
  });
}
