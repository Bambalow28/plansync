import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';

/// Persists all trips to the device via shared_preferences as a single JSON
/// blob. Small data, no backend — everything stays on-device.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const _key = 'plansync.trips.v1';

  Future<List<Trip>> loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTrips(List<Trip> trips) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(trips.map((t) => t.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
