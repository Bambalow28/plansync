import 'dart:convert';
import 'dart:io';
import '../models/category.dart';
import '../models/itinerary_item.dart';
import '../models/place.dart';

/// Thrown when a draft can't be produced; [message] is safe to show the user.
class AiItineraryException implements Exception {
  final String message;
  const AiItineraryException(this.message);
  @override
  String toString() => message;
}

/// Drafts an itinerary for a trip via the OpenAI Chat Completions API.
///
/// ponytail: the key is injected at build time (--dart-define, same as the
/// Unsplash/Mapbox keys) so it ships inside the app binary and can be
/// extracted. Fine for TestFlight; before a wide release put a Firebase
/// Function in front of this call and keep the key server-side.
class AiItineraryService {
  AiItineraryService._();
  static final AiItineraryService instance = AiItineraryService._();

  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String _model = 'gpt-4o';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Returns item builders shaped like [TripController.addItem]'s callback —
  /// the caller supplies the id once it's ready to persist them. Costs come
  /// back in [currency] and are sized to fit [budget] (0 = no budget given).
  Future<List<ItineraryItem Function(String id)>> generate({
    required Place destination,
    required DateTime start,
    required DateTime end,
    required double budget,
    required String currency,
    String? hotelAddress,
  }) async {
    if (!isConfigured) {
      throw const AiItineraryException('AI itineraries aren\'t set up in this build.');
    }
    final days = end.difference(start).inDays + 1;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.https('api.openai.com', '/v1/chat/completions'));
      req.headers
        ..set('authorization', 'Bearer $_apiKey')
        ..contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'model': _model,
        'max_tokens': (800 * days + 1000).clamp(2000, 12000),
        'messages': [
          {
            'role': 'user',
            'content': _prompt(destination, start, end, budget, currency, hotelAddress),
          },
        ],
      })));
      final res = await req.close().timeout(const Duration(seconds: 150));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        throw AiItineraryException(
          res.statusCode == 429 || res.statusCode >= 500
              ? 'The AI is busy right now. Try again in a minute.'
              : 'The AI service returned an error (${res.statusCode}).',
        );
      }
      final text = jsonDecode(body)['choices'][0]['message']['content'] as String;
      return parseItems(text, start, days);
    } on AiItineraryException {
      rethrow;
    } on FormatException {
      throw const AiItineraryException('Couldn\'t read the AI\'s response. Try again.');
    } on StateError {
      throw const AiItineraryException('Couldn\'t read the AI\'s response. Try again.');
    } catch (_) {
      throw const AiItineraryException('Couldn\'t reach the AI. Check your connection and try again.');
    } finally {
      client.close();
    }
  }

  /// Turns the model's JSON array into item builders, dropping any item whose
  /// day falls outside the trip.
  static List<ItineraryItem Function(String id)> parseItems(
    String text,
    DateTime start,
    int days,
  ) {
    final raw = (jsonDecode(_stripFences(text)) as List).cast<Map<String, dynamic>>();
    return [
      for (final r in raw)
        if (((r['day'] as num?)?.toInt() ?? 0) >= 0 && ((r['day'] as num?)?.toInt() ?? 0) < days)
          (String id) => _itemFrom(r, id, start),
    ];
  }

  /// Models sometimes wrap JSON in a ```json fence even when told not to.
  static String _stripFences(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.substring(t.indexOf('\n') + 1);
      final end = t.lastIndexOf('```');
      if (end != -1) t = t.substring(0, end);
    }
    return t.trim();
  }

  static ItineraryItem _itemFrom(Map<String, dynamic> raw, String id, DateTime start) {
    final day = start.add(Duration(days: (raw['day'] as num?)?.toInt() ?? 0));
    DateTime? time(String? hhmm) {
      final parts = hhmm?.split(':');
      if (parts == null || parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(day.year, day.month, day.day, h, m);
    }

    var end = time(raw['endTime'] as String?);
    if (end != null && raw['endsNextDay'] == true) {
      end = end.add(const Duration(days: 1));
    }

    final location = (raw['location'] as String?)?.trim();
    return ItineraryItem(
      id: id,
      title: (raw['what'] as String?)?.trim().isNotEmpty == true
          ? (raw['what'] as String).trim()
          : 'Plan',
      category: categoryFromName((raw['category'] as String?) ?? 'other'),
      day: day,
      start: time(raw['startTime'] as String?),
      end: end,
      location: location != null && location.isNotEmpty ? Place(city: location) : null,
      cost: (raw['cost'] as num?)?.toDouble() ?? 0,
      notes: (raw['notes'] as String?)?.trim() ?? '',
    );
  }

  String _prompt(
    Place destination,
    DateTime start,
    DateTime end,
    double budget,
    String currency,
    String? hotelAddress,
  ) {
    final days = end.difference(start).inDays + 1;
    final base = (hotelAddress != null && hotelAddress.trim().isNotEmpty)
        ? 'Each day starts from this hotel: "${hotelAddress.trim()}" — route the day\'s plans out from there and back.'
        : 'No hotel was given — start each day from a sensible general area of ${destination.label}.';
    final budgetLine = budget > 0
        ? 'The traveller\'s total budget is ${budget.round()} $currency for the whole trip, excluding flights to/from the destination. Choose places and price levels so the SUM of all item costs stays at or under it, and spend it sensibly — don\'t leave most of it unused.'
        : 'No budget was given — assume a comfortable mid-range trip.';
    return '''
Plan a $days-day itinerary for ${destination.label}, covering ${_isoDate(start)} through ${_isoDate(end)} inclusive.

$base

$budgetLine

Optimize for time efficiency, not just a checklist of attractions:
- Group each day around ONE geographic section/neighborhood of the destination. Fully explore that section before moving on.
- Only add a second section to the same day if it's close enough to the first to reach without significant backtracking — never zig-zag across the destination in one day.
- Along the way, schedule meals and drinks at well-reviewed, locally trending spots near wherever the itinerary is at that time of day.

Return ONLY a JSON array (no markdown, no commentary) of itinerary items, each shaped exactly like:
{"day": 0, "what": "...", "category": "activity", "startTime": "09:00", "endTime": "11:00", "endsNextDay": false, "location": "...", "cost": 0, "notes": ""}

Field rules:
- "day": 0-indexed day offset from the trip start (0 = first day, ${days - 1} = last day).
- "what": short-form description of the plan.
- "category": exactly one of flight, lodging, food, activity, transport, sightseeing, shopping, other.
- "startTime"/"endTime": 24-hour "HH:mm"; omit both for untimed items.
- "endsNextDay": true only if the plan runs past midnight into the next day, otherwise false.
- "location": short place/venue name — usually within ${destination.city}, but name the actual place if a plan happens elsewhere.
- "cost": estimated cost of that item in $currency for the traveller (a number, 0 if free). Include one "lodging" item per night with that night's rate — do not add a separate check-in item.
- "notes": anything the traveller should know (reservations, tips, what to bring) — empty string if nothing.
''';
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
