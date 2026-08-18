import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'place_search_service.dart';

/// One-shot "roughly where is the user" lookup, used only to bias the
/// suggested-destinations carousel toward the user's part of the world.
///
/// Every failure path — services off, permission denied or denied forever,
/// timeout, no matching city — returns null, and the caller shows the
/// unfiltered global list. Nothing here ever blocks the UI.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<String?>? _pending;
  String? _countryCode;
  bool _resolved = false;

  /// ISO country code for the user's position, or null if unavailable.
  /// Resolved once per app session and reused.
  Future<String?> countryCode() {
    if (_resolved) return Future.value(_countryCode);
    return _pending ??= _resolve().then((cc) {
      _countryCode = cc;
      _resolved = true;
      _pending = null;
      return cc;
    });
  }

  Future<String?> _resolve() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Country-level accuracy is all this needs, and the low setting is the
      // cheapest/fastest fix available.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final place = await PlaceSearchService.instance
          .nearest(position.latitude, position.longitude);
      final cc = place?.countryCode;
      return (cc == null || cc.isEmpty) ? null : cc;
    } catch (e) {
      debugPrint('Location lookup failed: $e');
      return null;
    }
  }
}
