import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/itinerary_item.dart';
import '../models/place.dart';
import '../services/attachment_service.dart';
import '../services/live_activity_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

/// In-memory store for all trips, backed by [StorageService]. Mutations
/// persist immediately and notify listeners.
class TripController extends ChangeNotifier {
  TripController._();
  static final TripController instance = TripController._();

  final List<Trip> _trips = [];
  bool _loaded = false;

  List<Trip> get trips {
    final list = [..._trips]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
  }

  bool get isLoaded => _loaded;

  // Simple monotonic id generator (avoids needing Date.now in tests).
  int _seq = 0;
  String _newId() {
    _seq++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_seq';
  }

  Future<void> load() async {
    _trips
      ..clear()
      ..addAll(await StorageService.instance.loadTrips());
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.instance.saveTrips(_trips);
    // Keep scheduled reminders + the Live Activity in sync (both no-op until
    // their services are enabled).
    NotificationService.instance.syncAll(_trips);
    LiveActivityService.instance.syncNext(_trips);
    notifyListeners();
  }

  Trip? tripById(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---- Trips ----------------------------------------------------------------

  Future<Trip> addTrip({
    required String name,
    required Place? destination,
    required DateTime startDate,
    required DateTime endDate,
    required double budget,
    required String currency,
  }) async {
    final trip = Trip(
      id: _newId(),
      name: name,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      budget: budget,
      currency: currency,
    );
    _trips.add(trip);
    await _persist();
    return trip;
  }

  Future<void> updateTrip(Trip trip) async => _persist();

  /// Imports a trip decoded from a shared link, giving it a fresh id so it
  /// can't clobber an existing trip. Returns the added trip.
  Future<Trip> importTrip(Trip decoded) async {
    final trip = Trip(
      id: _newId(),
      name: decoded.name,
      destination: decoded.destination,
      startDate: decoded.startDate,
      endDate: decoded.endDate,
      budget: decoded.budget,
      currency: decoded.currency,
      items: decoded.items,
      expenses: decoded.expenses,
    );
    _trips.add(trip);
    await _persist();
    return trip;
  }

  Future<void> deleteTrip(String id) async {
    final trip = tripById(id);
    if (trip != null) {
      final attachments = trip.items
          .expand((item) => item.attachments)
          .toList();
      await AttachmentService.instance.deleteAll(attachments);
    }
    _trips.removeWhere((t) => t.id == id);
    await _persist();
  }

  // ---- Itinerary items ------------------------------------------------------

  Future<void> addItem(
    String tripId,
    ItineraryItem Function(String id) build,
  ) async {
    final trip = tripById(tripId);
    if (trip == null) return;
    trip.items.add(build(_newId()));
    await _persist();
  }

  /// Same as [addItem] for a batch (e.g. an AI-drafted itinerary) — one
  /// persist for the whole set instead of one per item.
  Future<void> addItems(
    String tripId,
    List<ItineraryItem Function(String id)> builders,
  ) async {
    final trip = tripById(tripId);
    if (trip == null || builders.isEmpty) return;
    for (final build in builders) {
      trip.items.add(build(_newId()));
    }
    await _persist();
  }

  Future<void> updateItem(String tripId) async => _persist();

  Future<void> deleteItem(String tripId, String itemId) async {
    final trip = tripById(tripId);
    if (trip == null) return;
    final index = trip.items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      await AttachmentService.instance.deleteAll(trip.items[index].attachments);
    }
    trip.items.removeWhere((i) => i.id == itemId);
    await _persist();
  }
}
