import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/place.dart';

/// Result of an AeroDataBox flight lookup, shaped for the add-plan form.
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

/// Looks up scheduled flight details by flight number + date via AeroDataBox
/// (RapidAPI). Unlike the free AviationStack tier, this supports future
/// dates (up to ~365 days out on the free plan), so trips can be looked up
/// ahead of time instead of only on the day of travel.
///
/// Any failure returns null — the form falls back to manual entry.
class FlightLookupService {
  FlightLookupService._();
  static final FlightLookupService instance = FlightLookupService._();

  // Personal AeroDataBox (RapidAPI) access key.
  static const String _rapidApiKey =
      '308e8a5531msha94fa3985504da4p16ddc1jsn3a9b8cd584a5';
  static const String _host = 'aerodatabox.p.rapidapi.com';

  Future<FlightInfo?> lookup(String rawCode, {DateTime? day}) async {
    final code = rawCode.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (code.isEmpty) return null;

    final date = _formattedDate(day ?? DateTime.now());
    final uri = Uri.https(_host, '/flights/number/$code/$date');

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(uri);
      request.headers
        ..set('X-RapidAPI-Key', _rapidApiKey)
        ..set('X-RapidAPI-Host', _host);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        debugPrint('Flight lookup HTTP ${response.statusCode}: $body');
        return null;
      }

      final data = jsonDecode(body) as List?;
      if (data == null || data.isEmpty) return null;

      final f = data.first as Map<String, dynamic>;
      final dep = (f['departure'] ?? const {}) as Map<String, dynamic>;
      final arr = (f['arrival'] ?? const {}) as Map<String, dynamic>;
      final airline = (f['airline'] ?? const {}) as Map<String, dynamic>;
      final depAirport = (dep['airport'] ?? const {}) as Map<String, dynamic>;
      final arrAirport = (arr['airport'] ?? const {}) as Map<String, dynamic>;

      final depSched = _localTime(dep['scheduledTime']);
      final arrSched = _localTime(arr['scheduledTime']);

      return FlightInfo(
        flightIata:
            (f['number'] as String?)?.toUpperCase().replaceAll(' ', '') ??
            code,
        airlineName: airline['name'] as String?,
        departure: _place((depAirport['name'] ?? depAirport['municipalityName']) as String?),
        departureCode: (depAirport['iata'] as String?)?.toUpperCase(),
        departureMinutes: _minutesOf(depSched),
        arrival: _place((arrAirport['name'] ?? arrAirport['municipalityName']) as String?),
        arrivalCode: (arrAirport['iata'] as String?)?.toUpperCase(),
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

  /// AeroDataBox nests local time under scheduledTime.local, formatted like
  /// "2026-08-15 07:45-07:00" (space-separated, not ISO 'T').
  static String? _localTime(Object? scheduledTime) {
    if (scheduledTime is! Map) return null;
    final local = scheduledTime['local'] as String?;
    if (local == null) return null;
    return local.replaceFirst(' ', 'T');
  }

  static Place? _place(String? airport) {
    final a = airport?.trim();
    if (a == null || a.isEmpty) return null;
    return Place(city: a);
  }

  /// Reads HH:mm directly out of the local-time string so it isn't shifted
  /// by a UTC offset — [scheduled] is already the airport-local wall-clock.
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
