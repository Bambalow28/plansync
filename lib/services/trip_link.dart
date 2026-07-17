import 'dart:convert';
import 'dart:io';
import '../models/trip.dart';

/// Self-contained `plansync://` deep link for a trip. The whole itinerary
/// (minus documents/attachments) is gzipped + base64url-encoded into the link,
/// so it can be pasted into a TravelSync post and opened with no backend.
class TripLink {
  TripLink._();

  static const scheme = 'plansync';
  static const host = 'trip';

  /// Builds `plansync://trip?d=<base64url(gzip(json))>` (attachments excluded).
  static Uri encode(Trip trip) {
    final map = trip.toJson();
    for (final item in (map['items'] as List)) {
      (item as Map).remove('attachments');
    }
    final bytes = GZipCodec().encode(utf8.encode(jsonEncode(map)));
    return Uri(scheme: scheme, host: host, queryParameters: {'d': base64Url.encode(bytes)});
  }

  /// Decodes a `plansync://trip?d=…` link back into a Trip (keeps the original
  /// id; the importer assigns a fresh one). Returns null if it isn't a valid
  /// trip link.
  static Trip? decode(Uri uri) {
    if (uri.scheme != scheme || uri.host != host) return null;
    final d = uri.queryParameters['d'];
    if (d == null || d.isEmpty) return null;
    try {
      final json = utf8.decode(GZipCodec().decode(base64Url.decode(d)));
      return Trip.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
