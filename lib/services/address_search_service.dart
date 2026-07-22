import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Address/place autocomplete via the Mapbox Geocoding API — unlike
/// [PlaceSearchService]'s offline city dataset, this needs the network for
/// every keystroke. Matches addresses, points of interest, and cities/regions
/// /countries, so typing a hotel name, street, or just a city still returns
/// something useful. Any failure (missing key, offline, bad response) just
/// returns no suggestions; the field still accepts freely-typed text.
class AddressSearchService {
  AddressSearchService._();
  static final AddressSearchService instance = AddressSearchService._();

  // Injected at build time via --dart-define=MAPBOX_API_KEY=... (see
  // .github/workflows/testflight.yml); empty for local `flutter run`/`flutter
  // test`, which just makes autocomplete return no suggestions.
  static const String _apiKey = String.fromEnvironment('MAPBOX_API_KEY');
  static const String _host = 'api.mapbox.com';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<String>> search(String query) async {
    final q = query.trim();
    if (_apiKey.isEmpty) {
      debugPrint('Mapbox geocoding skipped: MAPBOX_API_KEY not set (pass --dart-define when running locally).');
      return const [];
    }
    if (q.length < 3) return const [];

    final uri = Uri.https(_host, '/geocoding/v5/mapbox.places/$q.json', {
      'access_token': _apiKey,
      'types': 'address,poi,place,locality,region,country',
      'autocomplete': 'true',
      'limit': '5',
    });

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('Mapbox geocoding HTTP ${response.statusCode}: $body');
        return const [];
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? const [];
      return [
        for (final f in features)
          (f as Map<String, dynamic>)['place_name'] as String,
      ];
    } catch (e) {
      debugPrint('Mapbox geocoding failed: $e');
      return const [];
    } finally {
      client?.close(force: true);
    }
  }
}
