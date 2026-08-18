import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plansync/services/unsplash_service.dart';

/// The photo cache is what keeps the app off the 50-requests-per-hour demo
/// limit: without it every city is re-resolved on every cold start. These
/// cover the part that runs with no API key present (as in CI) — that a
/// persisted url is readable synchronously on the next launch, and that an
/// unconfigured build stays quiet rather than throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a persisted url is readable synchronously after warmUp', () async {
    SharedPreferences.setMockInitialValues({
      'unsplash_urls_v1': jsonEncode({
        'Kyoto Japan travel': 'https://images.example/kyoto.jpg',
      }),
    });

    await UnsplashService.instance.warmUp();

    // Synchronous: this is what lets a card paint its photo on frame one
    // instead of flashing the gradient while a future resolves.
    expect(
      UnsplashService.instance.cachedUrl('Kyoto Japan travel'),
      'https://images.example/kyoto.jpg',
    );
    // Whitespace shouldn't produce a miss and burn a request.
    expect(
      UnsplashService.instance.cachedUrl('  Kyoto Japan travel  '),
      'https://images.example/kyoto.jpg',
    );
    expect(UnsplashService.instance.cachedUrl('Lisbon Portugal travel'), isNull);
  });

  test('an unconfigured build resolves to null instead of throwing', () async {
    // No --dart-define=UNSPLASH_API_KEY in tests, so this is the real path CI
    // and local `flutter run` take.
    expect(UnsplashService.instance.isConfigured, isFalse);
    expect(await UnsplashService.instance.photoUrl('Lisbon Portugal travel'), isNull);
    expect(await UnsplashService.instance.photoUrl(''), isNull);
  });

  test('a cached url is returned without needing a key', () async {
    // Proves the persisted map is consulted before the configured-key check —
    // an expired or removed key must not blank out photos already on disk.
    expect(
      await UnsplashService.instance.photoUrl('Kyoto Japan travel'),
      'https://images.example/kyoto.jpg',
    );
  });
}
