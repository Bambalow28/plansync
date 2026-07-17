import 'package:flutter_test/flutter_test.dart';

import 'package:plansync/models/category.dart';
import 'package:plansync/models/itinerary_item.dart';
import 'package:plansync/models/place.dart';
import 'package:plansync/models/trip.dart';
import 'package:plansync/services/itinerary_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 8, 1);
  final trip = Trip(
    id: 't1',
    name: 'Japan Trip',
    destination: const Place(city: 'Tokyo', country: 'Japan'),
    startDate: start,
    endDate: start.add(const Duration(days: 1)),
    budget: 1000,
    currency: 'USD',
    items: [
      ItineraryItem(
        id: 'i1',
        title: 'Flight to Tokyo',
        category: PlanCategory.flight,
        day: start,
        start: DateTime(2026, 8, 1, 9, 0),
        end: DateTime(2026, 8, 1, 17, 0),
        cost: 450,
        flightCode: 'NH10',
        departureCode: 'SFO',
        arrivalCode: 'HND',
      ),
      ItineraryItem(
        id: 'i2',
        title: 'Ramen Dinner',
        category: PlanCategory.food,
        day: start,
        start: DateTime(2026, 8, 1, 19, 0),
        end: DateTime(2026, 8, 1, 20, 0),
        cost: 25,
        location: const Place(city: 'Shibuya'),
      ),
    ],
  );

  test('builds a non-empty PDF for a trip', () async {
    final bytes = await ItineraryPdf.buildBytes(trip);
    expect(bytes, isNotEmpty);
    // PDF files start with the "%PDF-" magic header.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
