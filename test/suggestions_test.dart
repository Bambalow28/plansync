import 'package:flutter_test/flutter_test.dart';

import 'package:plansync/data/suggested_places.dart';
import 'package:plansync/services/place_search_service.dart';

void main() {
  test('suggestions rank in-season first, then the user\'s own region', () {
    // July: Bali/Cusco/Vancouver are in season, Bangkok/Rio are not.
    final ordered = suggestionsFor(month: 7, region: Region.americas);
    expect(ordered.length, kSuggestedPlaces.length, reason: 'nothing is dropped');
    expect(
      ordered.map((p) => p.city).toSet(),
      kSuggestedPlaces.map((p) => p.city).toSet(),
      reason: 'no duplicates or omissions',
    );

    int rankOf(String city) => ordered.indexWhere((p) => p.city == city);
    // In-season + user's region beats in-season elsewhere...
    expect(rankOf('Cusco'), lessThan(rankOf('Bali')));
    // ...which in turn beats out-of-season anywhere.
    expect(rankOf('Bali'), lessThan(rankOf('Bangkok')));
    // Out-of-season in the user's region still beats out-of-season abroad.
    expect(rankOf('Rio de Janeiro'), lessThan(rankOf('Bangkok')));
  });

  test('an unknown region leaves the seasonal order intact', () {
    final ordered = suggestionsFor(month: 7);
    final inSeason = ordered.takeWhile((p) => p.months.contains(7));
    expect(inSeason.length, kSuggestedPlaces.where((p) => p.months.contains(7)).length);
  });

  test('regionForCountry maps known codes and shrugs at the rest', () {
    expect(regionForCountry('us'), Region.americas);
    expect(regionForCountry('JP'), Region.asia);
    expect(regionForCountry('ZZ'), isNull);
    expect(regionForCountry(null), isNull);
  });

  test('nearest() resolves a coordinate to the right country', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final svc = PlaceSearchService.instance;
    // Roughly central Tokyo.
    expect((await svc.nearest(35.68, 139.69))?.countryCode, 'JP');
    // Roughly Manhattan.
    expect((await svc.nearest(40.71, -74.01))?.countryCode, 'US');
    // Just west of the antimeridian near Fiji — the longitude wrap must not
    // send this to the far side of the world.
    final fiji = await svc.nearest(-18.14, 178.44);
    expect(fiji?.countryCode, 'FJ');
  });
}
