import 'package:flutter_test/flutter_test.dart';
import 'package:plansync/controllers/trip_controller.dart';
import 'package:plansync/models/trip.dart';
import 'package:plansync/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Trip _trip(String id, String name) => Trip(
  id: id,
  name: name,
  startDate: DateTime(2026, 6, 1),
  endDate: DateTime(2026, 6, 5),
  budget: 0,
  currency: 'USD',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.load();
    await TripController.instance.load();
  });

  test('mergeTrips adds only trips this phone lacks and keeps local ones', () async {
    final c = TripController.instance;
    await c.mergeTrips([_trip('a', 'Local Japan')]);
    final added = await c.mergeTrips([_trip('a', 'Backup Japan'), _trip('b', 'Peru')]);
    expect(added, 1);
    expect(c.trips.map((t) => t.name).toSet(), {'Local Japan', 'Peru'});
  });

  test('deleteAll empties the trips', () async {
    final c = TripController.instance;
    await c.mergeTrips([_trip('a', 'x')]);
    await c.deleteAll();
    expect(c.trips, isEmpty);
  });

  test('settings default sensibly and persist', () async {
    final s = SettingsService.instance;
    expect(s.autoBackup, isTrue);
    expect(s.defaultCurrency, 'USD');
    await s.setDefaultCurrency('EUR');
    await s.setAutoBackup(false);
    expect(s.defaultCurrency, 'EUR');
    expect(s.autoBackup, isFalse);
    await s.setDefaultCurrency('XXX'); // unknown falls back
    expect(s.defaultCurrency, 'USD');
  });
}
