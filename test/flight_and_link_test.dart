import 'package:flutter_test/flutter_test.dart';

import 'package:plansync/models/category.dart';
import 'package:plansync/models/itinerary_item.dart';
import 'package:plansync/models/place.dart';
import 'package:plansync/models/trip.dart';
import 'package:plansync/services/trip_link.dart';

void main() {
  final d = DateTime(2026, 8, 1);

  test('flight fields round-trip through JSON', () {
    final item = ItineraryItem(
      id: 'f1',
      title: 'Flight to Osaka',
      category: PlanCategory.flight,
      day: d,
      start: DateTime(2026, 8, 1, 9, 0),
      end: DateTime(2026, 8, 1, 10, 15),
      flightCode: 'DL299',
      airlineName: 'Delta Air Lines',
      location: const Place(city: 'Tokyo', country: 'Japan'),
      arrivalLocation: const Place(city: 'Osaka', country: 'Japan'),
      departureCode: 'HND',
      arrivalCode: 'ITM',
    );
    final back = ItineraryItem.fromJson(item.toJson());
    expect(back.isFlight, isTrue);
    expect(back.flightCode, 'DL299');
    expect(back.airlineName, 'Delta Air Lines');
    expect(back.departureCode, 'HND');
    expect(back.arrivalCode, 'ITM');
    expect(back.arrivalLocation?.city, 'Osaka');
  });

  test('old JSON without flight fields still loads', () {
    final legacy = {
      'id': 'x',
      'title': 'Museum',
      'category': 'activity',
      'day': d.toIso8601String(),
    };
    final item = ItineraryItem.fromJson(legacy);
    expect(item.isFlight, isFalse);
    expect(item.flightCode, isNull);
    expect(item.arrivalLocation, isNull);
  });

  test('TripLink encode/decode round-trips a trip (without attachments)', () {
    final trip = Trip(
      id: 't1',
      name: 'Japan 2026',
      destination: const Place(city: 'Tokyo', country: 'Japan'),
      startDate: d,
      endDate: d.add(const Duration(days: 3)),
      budget: 2000,
      currency: 'JPY',
      cover: TripCover.sunset,
      items: [
        ItineraryItem(
          id: 'i1',
          title: 'Flight',
          category: PlanCategory.flight,
          day: d,
          flightCode: 'DL299',
        ),
      ],
    );

    final uri = TripLink.encode(trip);
    expect(uri.scheme, 'plansync');
    expect(uri.host, 'trip');

    final decoded = TripLink.decode(uri);
    expect(decoded, isNotNull);
    expect(decoded!.name, 'Japan 2026');
    expect(decoded.currency, 'JPY');
    expect(decoded.cover, TripCover.sunset);
    expect(decoded.items.single.flightCode, 'DL299');
  });

  test('TripLink.decode rejects a non-trip URI', () {
    expect(TripLink.decode(Uri.parse('https://example.com')), isNull);
    expect(TripLink.decode(Uri.parse('plansync://trip')), isNull);
  });
}
