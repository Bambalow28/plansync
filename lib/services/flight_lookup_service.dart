import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

/// Result of an AviationStack flight lookup, shaped for the add-plan form.
///
/// Times are the airport-local wall-clock, expressed as minutes-from-midnight
/// (the same unit the form uses). [endDayOffset] is how many calendar days
/// after departure the flight arrives (0 = same day, 1 = overnight).
class FlightInfo {
  final String flightIata;
  final String? airlineName;

  final Place? departure; // airport as a Place label
  final String? departureCode; // IATA
  final int? departureMinutes;

  final Place? arrival;
  final String? arrivalCode;
  final int? arrivalMinutes;

  final int endDayOffset;

  const FlightInfo({
    required this.flightIata,
    this.airlineName,
    this.departure,
    this.departureCode,
    this.departureMinutes,
    this.arrival,
    this.arrivalCode,
    this.arrivalMinutes,
    this.endDayOffset = 0,
  });
}

/// Looks up scheduled flight details by flight number via AviationStack.
///
/// The free AviationStack plan is HTTP-only, so this hits the cleartext
/// endpoint (iOS needs the matching App Transport Security exception in
/// Info.plist). Any failure returns null — the form falls back to manual entry.
class FlightLookupService {
  FlightLookupService._();
  static final FlightLookupService instance = FlightLookupService._();

  // Personal AviationStack access key.
  static const String _accessKey = '38f0ae405cabbdd58880a6f4562d76ed';
  static const String _host = 'api.aviationstack.com';

  Future<FlightInfo?> lookup(String rawCode, {DateTime? day}) async {
    final code = rawCode.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (code.isEmpty) return null;

    final query = {'access_key': _accessKey, 'flight_iata': code, 'limit': '1'};
    if (day != null) {
      query['flight_date'] = _formattedDate(day);
    }
    final uri = Uri.http(_host, '/v1/flights', query);

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('Flight lookup HTTP ${response.statusCode}: $body');
        return null;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      // AviationStack reports auth/quota problems in an "error" object.
      if (json['error'] != null) {
        debugPrint('Flight lookup error: ${json['error']}');
        return null;
      }
      final data = json['data'] as List?;
      if (data == null || data.isEmpty) return null;

      final f = data.first as Map<String, dynamic>;
      final dep = (f['departure'] ?? const {}) as Map<String, dynamic>;
      final arr = (f['arrival'] ?? const {}) as Map<String, dynamic>;
      final airline = (f['airline'] ?? const {}) as Map<String, dynamic>;
      final flight = (f['flight'] ?? const {}) as Map<String, dynamic>;

      final depSched = dep['scheduled'] as String?;
      final arrSched = arr['scheduled'] as String?;

      return FlightInfo(
        flightIata: (flight['iata'] as String?)?.toUpperCase() ?? code,
        airlineName: airline['name'] as String?,
        departure: _place(dep['airport'] as String?),
        departureCode: (dep['iata'] as String?)?.toUpperCase(),
        departureMinutes: _minutesOf(depSched),
        arrival: _place(arr['airport'] as String?),
        arrivalCode: (arr['iata'] as String?)?.toUpperCase(),
        arrivalMinutes: _minutesOf(arrSched),
        endDayOffset: _dayOffset(depSched, arrSched),
      );
    } catch (e) {
      debugPrint('Flight lookup failed: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  static Place? _place(String? airport) {
    final a = airport?.trim();
    if (a == null || a.isEmpty) return null;
    return Place(city: a);
  }

  /// AviationStack encodes the airport-local wall-clock time in the scheduled
  /// string ("2026-07-07T14:45:00+00:00"); read HH:mm directly so it isn't
  /// shifted by the +00:00 offset.
  static int? _minutesOf(String? scheduled) {
    final t = _timePart(scheduled);
    if (t == null) return null;
    final h = int.tryParse(t.substring(0, 2));
    final m = int.tryParse(t.substring(3, 5));
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static int _dayOffset(String? depSched, String? arrSched) {
    final d = _datePart(depSched);
    final a = _datePart(arrSched);
    if (d != null && a != null) {
      final diff = a.difference(d).inDays;
      if (diff >= 0) return diff;
    }
    // Fallback: if we only have times and arrival is earlier, it's overnight.
    final dm = _minutesOf(depSched);
    final am = _minutesOf(arrSched);
    if (dm != null && am != null && am < dm) return 1;
    return 0;
  }

  static String? _timePart(String? s) {
    if (s == null || !s.contains('T')) return null;
    final t = s.split('T')[1];
    return t.length >= 5 ? t : null;
  }

  static DateTime? _datePart(String? s) {
    if (s == null || !s.contains('T')) return null;
    return DateTime.tryParse(s.split('T')[0]);
  }

  static String _formattedDate(DateTime day) {
    final year = day.year.toString().padLeft(4, '0');
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '$year-$month-$dayOfMonth';
  }
}
