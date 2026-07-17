import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/place.dart';

/// Fully offline city autocomplete backed by the bundled
/// `assets/data/cities.json` (≈34k cities worldwide, pre-sorted by population
/// so the most relevant matches surface first). No network required.
class PlaceSearchService {
  PlaceSearchService._();
  static final instance = PlaceSearchService._();

  List<_City>? _cities;
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/cities.json');
      final list = jsonDecode(raw) as List;
      _cities = [
        for (final e in list)
          _City(
            name: e['n'] as String,
            ascii: e['a'] as String,
            country: e['c'] as String,
            cc: e['cc'] as String,
            lat: (e['y'] as num?)?.toDouble(),
            lon: (e['x'] as num?)?.toDouble(),
          ),
      ];
    } catch (e) {
      debugPrint('Cities dataset load failed: $e');
      _cities = const [];
    }
  }

  /// Diacritic-insensitive lowercasing for matching (e.g. "São" → "sao").
  static String _fold(String s) {
    const from = 'àáâãäåāçćčèéêëēėęìíîïīįñńòóôõöøōùúûüūýÿ';
    const to = 'aaaaaaaccceeeeeeeiiiiiinnooooooouuuuuyy';
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
      final c = String.fromCharCode(ch);
      final idx = from.indexOf(c);
      buf.write(idx >= 0 ? to[idx] : c);
    }
    return buf.toString();
  }

  /// Up to [limit] city matches for [query]. Prefix matches rank above
  /// substring matches; within each group the dataset's population order wins.
  Future<List<Place>> search(String query, {int limit = 8}) async {
    final q = _fold(query.trim());
    if (q.length < 2) return const [];
    await ensureLoaded();
    final cities = _cities!;

    final prefix = <Place>[];
    final contains = <Place>[];
    for (final c in cities) {
      if (c.ascii.startsWith(q)) {
        prefix.add(c.toPlace());
        if (prefix.length >= limit) break;
      }
    }
    if (prefix.length < limit) {
      for (final c in cities) {
        if (!c.ascii.startsWith(q) && c.ascii.contains(q)) {
          contains.add(c.toPlace());
          if (prefix.length + contains.length >= limit) break;
        }
      }
    }
    return [...prefix, ...contains];
  }
}

class _City {
  final String name;
  final String ascii;
  final String country;
  final String cc;
  final double? lat;
  final double? lon;
  const _City({
    required this.name,
    required this.ascii,
    required this.country,
    required this.cc,
    this.lat,
    this.lon,
  });

  Place toPlace() => Place(city: name, country: country, countryCode: cc, lat: lat, lon: lon);
}
