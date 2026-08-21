import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Destination photos via the Unsplash Search API.
///
/// Resolved urls are persisted, which matters more than it sounds: the demo
/// tier allows 50 requests an hour, and re-resolving every city on every cold
/// start burned through that in a handful of launches — after which every
/// lookup failed and the whole app silently fell back to gradients. With the
/// map on disk each city costs one request ever, not one per launch.
///
/// Any failure (missing key, offline, rate limit, no results) returns null and
/// the caller keeps its gradient.
class UnsplashService {
  UnsplashService._();
  static final UnsplashService instance = UnsplashService._();

  // Injected at build time via --dart-define=UNSPLASH_API_KEY=... (see
  // .github/workflows/testflight.yml); empty for local `flutter run`/`flutter
  // test`, which just makes every surface keep its gradient.
  static const String _apiKey = String.fromEnvironment('UNSPLASH_API_KEY');
  static const String _host = 'api.unsplash.com';
  static const String _prefsKey = 'unsplash_urls_v1';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// query -> photo url. Successes only; a miss is retried on a later run.
  Map<String, String> _urls = {};

  /// Queries that returned no photo this session — not persisted, so a bad
  /// search term gets another chance next launch.
  final Set<String> _misses = {};

  /// In-flight lookups, so two cards for the same city share one request.
  final Map<String, Future<String?>> _inFlight = {};

  Future<void>? _warming;
  bool _ready = false;

  /// Loads the persisted url map. Called once from `main()` before the first
  /// frame so [cachedUrl] is populated when the first card builds.
  Future<void> warmUp() => _warming ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _urls = {
          for (final e in decoded.entries)
            if (e.value is String) e.key: e.value as String,
        };
      }
    } catch (e) {
      debugPrint('Unsplash cache load failed: $e');
    }
    _ready = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_urls));
    } catch (e) {
      debugPrint('Unsplash cache save failed: $e');
    }
  }

  /// An already-resolved url for [query], without waiting — lets a widget paint
  /// its photo on the very first frame instead of flashing the gradient.
  String? cachedUrl(String query) => _urls[query.trim()];

  /// A photo url for [query], or null if one can't be had.
  Future<String?> photoUrl(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    if (!_ready) await warmUp();
    // The cache is consulted before the key: a build without one (or with an
    // expired one) must still show every photo already resolved to disk,
    // rather than reverting the whole app to gradients.
    final cached = _urls[q];
    if (cached != null) return cached;
    if (!isConfigured || _misses.contains(q)) return null;
    return _inFlight[q] ??= _fetch(q).whenComplete(() => _inFlight.remove(q));
  }

  Future<String?> _fetch(String query) async {
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
        // 403 with no remaining quota is the rate limit, not a bad key — worth
        // saying plainly, since the symptom (everything grey) is identical.
        final remaining = response.headers.value('x-ratelimit-remaining');
        if (response.statusCode == 403 && remaining == '0') {
          debugPrint(
            'Unsplash rate limit reached (50/hour on the demo tier). '
            'Photos already cached still show; new cities stay on their gradient '
            'until the hour rolls over.',
          );
        } else {
          debugPrint('Unsplash HTTP ${response.statusCode}: $body');
        }
        return null;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? const [];
      if (results.isEmpty) {
        _misses.add(query);
        return null;
      }
      final urls = (results.first as Map<String, dynamic>)['urls'] as Map<String, dynamic>?;
      // "regular" is 1080px wide — a card is at most 400pt across, but on a
      // 3x device that's ~1200 real pixels; "small" (400px) was stretched
      // ~3x and read as blurry.
      final url = (urls?['regular'] ?? urls?['small']) as String?;
      if (url == null) {
        _misses.add(query);
        return null;
      }
      _urls[query] = url;
      unawaited(_persist());
      return url;
    } catch (e) {
      // Not remembered: a transient offline blip shouldn't poison the query.
      debugPrint('Unsplash lookup failed: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}
