import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Destination photos via the Unsplash Search API. Like [AddressSearchService]
/// this needs the network; any failure (missing key, offline, bad response, no
/// results) just returns null and the caller keeps its gradient fallback.
///
/// ponytail: photos are cached in memory only (Flutter's ImageCache holds the
/// decoded image for the session) plus this url map, so a cold start refetches.
/// Add `cached_network_image` if surviving restarts is worth the dependency.
class UnsplashService {
  UnsplashService._();
  static final UnsplashService instance = UnsplashService._();

  // Injected at build time via --dart-define=UNSPLASH_API_KEY=... (see
  // .github/workflows/testflight.yml); empty for local `flutter run`/`flutter
  // test`, which just makes every surface keep its gradient.
  static const String _apiKey = String.fromEnvironment('UNSPLASH_API_KEY');
  static const String _host = 'api.unsplash.com';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Resolved urls (and misses, as null) keyed by query, so the same city
  /// doesn't burn a request per card rebuild — the free tier is 50 req/hour.
  final Map<String, String?> _cache = {};

  /// In-flight lookups, so two cards for the same city share one request.
  final Map<String, Future<String?>> _inFlight = {};

  /// A landscape photo url for [query], or null if one can't be had.
  Future<String?> photoUrl(String query) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(null);
    if (_cache.containsKey(q)) return Future.value(_cache[q]);
    return _inFlight[q] ??= _fetch(q).whenComplete(() => _inFlight.remove(q));
  }

  /// An already-resolved url for [query], without waiting. Lets a widget paint
  /// its photo on the very first frame instead of flashing the gradient while
  /// a Future that's already completed comes back around.
  String? cachedUrl(String query) => _cache[query.trim()];

  Future<String?> _fetch(String query) async {
    if (_apiKey.isEmpty) {
      debugPrint('Unsplash skipped: UNSPLASH_API_KEY not set (pass --dart-define when running locally).');
      return null;
    }

    final uri = Uri.https(_host, '/search/photos', {
      'query': query,
      'per_page': '1',
      'orientation': 'landscape',
      'content_filter': 'high',
    });

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Client-ID $_apiKey');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('Unsplash HTTP ${response.statusCode}: $body');
        return null;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? const [];
      if (results.isEmpty) return _cache[query] = null;
      final urls = (results.first as Map<String, dynamic>)['urls'] as Map<String, dynamic>?;
      return _cache[query] = urls?['regular'] as String?;
    } catch (e) {
      // Not cached: a transient offline blip shouldn't poison the query for
      // the rest of the session the way a genuine "no such photo" does.
      debugPrint('Unsplash lookup failed: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
