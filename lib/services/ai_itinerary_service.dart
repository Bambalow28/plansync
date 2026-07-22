import '../models/category.dart';
import '../models/itinerary_item.dart';
import '../models/place.dart';

/// Drafts an itinerary for a trip via an AI provider.
///
/// ponytail: Gemini is disconnected for now (repeated free-tier/billing
/// quota failures made it unusable for testing) — [generate] is a stub that
/// always returns no items, so a trip is still created, just with an empty
/// itinerary. The prompt ([_prompt]) and JSON-item parsing ([_itemFrom],
/// [_stripFences]) below are provider-agnostic — when wiring up a different
/// provider, build its request from [_prompt] and feed its JSON array
/// response through [_itemFrom] rather than rewriting either.
class AiItineraryService {
  AiItineraryService._();
  static final AiItineraryService instance = AiItineraryService._();

  /// Returns item builders shaped like [TripController.addItem]'s callback —
  /// the caller supplies the id once it's ready to persist them.
  Future<List<ItineraryItem Function(String id)>> generate({
    required Place destination,
    required DateTime start,
    required DateTime end,
    String? hotelAddress,
    void Function(PlanCategory category)? onProgress,
  }) async {
    // Brief pause so the caller's progress UI doesn't just flash instantly.
    await Future.delayed(const Duration(milliseconds: 600));
    return const [];
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

  ItineraryItem _itemFrom(Map<String, dynamic> raw, String id, DateTime start) {
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

  String _prompt(Place destination, DateTime start, DateTime end, String? hotelAddress) {
    final days = end.difference(start).inDays + 1;
    final base = (hotelAddress != null && hotelAddress.trim().isNotEmpty)
        ? 'Each day starts from this hotel: "${hotelAddress.trim()}" — route the day\'s plans out from there and back.'
        : 'No hotel was given — start each day from a sensible general area of ${destination.label}.';
    return '''
Plan a $days-day itinerary for ${destination.label}, covering ${_isoDate(start)} through ${_isoDate(end)} inclusive.

$base

Optimize for time efficiency, not just a checklist of attractions:
- Group each day around ONE geographic section/neighborhood of the destination. Fully explore that section before moving on.
- Only add a second section to the same day if it's close enough to the first to reach without significant backtracking — never zig-zag across the destination in one day.
- Along the way, schedule meals and drinks at well-reviewed, locally trending spots near wherever the itinerary is at that time of day.

Return ONLY a JSON array (no markdown, no commentary) of itinerary items, each shaped exactly like:
{"day": 0, "what": "...", "category": "activity", "startTime": "09:00", "endTime": "11:00", "endsNextDay": false, "location": "...", "cost": null, "notes": ""}

Field rules:
- "day": 0-indexed day offset from the trip start (0 = first day, ${days - 1} = last day).
- "what": short-form description of the plan.
- "category": exactly one of flight, lodging, food, activity, transport, sightseeing, shopping, other.
- "startTime"/"endTime": 24-hour "HH:mm"; omit both for untimed items.
- "endsNextDay": true only if the plan runs past midnight into the next day, otherwise false.
- "location": short place/venue name — usually within ${destination.city}, but name the actual place if a plan happens elsewhere.
- "cost": rough USD estimate per item, or null if you aren't confident enough to guess.
- "notes": anything the traveller should know (reservations, tips, what to bring) — empty string if nothing.
''';
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
