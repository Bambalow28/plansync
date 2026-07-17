import 'attachment.dart';
import 'category.dart';
import 'place.dart';
import '../utils/format.dart';

/// A single planned event within a trip, anchored to a calendar [day] (the day
/// it appears under in the timeline) with optional full-datetime [start]/[end]
/// — full datetimes so e.g. an overnight flight can end on a later date. Its
/// [cost] feeds the trip budget; [attachments] are documents on the device.
class ItineraryItem {
  final String id;
  String title;
  Place? location;
  String notes;
  PlanCategory category;

  /// The calendar day this item is grouped under (time component ignored).
  DateTime day;

  DateTime? start;
  DateTime? end;

  double cost;
  List<Attachment> attachments;

  /// Minutes before [start] to fire a heads-up local notification. Null = no
  /// reminder.
  int? reminderLeadMinutes;

  // ---- Flight fields (only meaningful when category == flight) --------------
  // These are exactly what a flight-lookup API would fill later, so adding one
  // means writing a service that populates these — no model change needed.

  /// Airline + number, e.g. "DL299".
  String? flightCode;

  /// Human airline name, e.g. "Delta Air Lines" (filled by a lookup or typed).
  String? airlineName;

  /// The arrival ("To") place; [location] doubles as the departure ("From").
  Place? arrivalLocation;

  /// Optional IATA codes shown big on the flight card, e.g. "SFO" / "HND".
  String? departureCode;
  String? arrivalCode;

  bool get isFlight => category == PlanCategory.flight;

  String get locationLabel => location?.label ?? '';
  bool get hasLocation => location != null;
  int? get startMinutes =>
      start != null ? (start!.hour * 60 + start!.minute) : null;
  int? get endMinutes => end != null ? (end!.hour * 60 + end!.minute) : null;

  ItineraryItem({
    required this.id,
    required this.title,
    this.location,
    this.notes = '',
    this.category = PlanCategory.activity,
    required this.day,
    this.start,
    this.end,
    this.cost = 0,
    List<Attachment>? attachments,
    this.reminderLeadMinutes,
    this.flightCode,
    this.airlineName,
    this.arrivalLocation,
    this.departureCode,
    this.arrivalCode,
  }) : attachments = attachments ?? [] {
    _normalizeOvernight();
  }

  /// An [end] that lands before [start] is impossible within a single day — it
  /// means the plan runs past midnight (e.g. a red-eye 11:30 PM → 6:00 AM). Roll
  /// [end] forward whole days until it sits after [start] so [spansDays] and the
  /// timeline treat it as crossing into the next day. Zero-duration plans
  /// (end == start) are left untouched.
  void _normalizeOvernight() {
    var e = end;
    final s = start;
    if (s == null || e == null) return;
    while (e!.isBefore(s)) {
      e = e.add(const Duration(days: 1));
    }
    end = e;
  }

  /// Sort key within a day: timed items first (by time of day), untimed last.
  int get sortKey =>
      start != null ? start!.hour * 60 + start!.minute : 24 * 60 + 1;

  /// True when start and end fall on different calendar dates (e.g. a red-eye).
  bool get spansDays =>
      start != null &&
      end != null &&
      (start!.year != end!.year ||
          start!.month != end!.month ||
          start!.day != end!.day);

  int get spanDays => spansDays ? end!.difference(start!).inDays : 0;

  bool occursOn(DateTime day) {
    final date = _dateOnly(day);
    if (start != null && end != null) {
      final startDay = _dateOnly(start!);
      final endDay = _dateOnly(end!);
      return !date.isBefore(startDay) && !date.isAfter(endDay);
    }
    return _dateOnly(this.day) == date;
  }

  bool isStartDay(DateTime day) =>
      start != null && _dateOnly(start!) == _dateOnly(day);

  bool isEndDay(DateTime day) =>
      end != null && _dateOnly(end!) == _dateOnly(day);

  int displaySortKey(DateTime day) {
    if (start != null && _dateOnly(start!) == _dateOnly(day)) {
      return startMinutes!;
    }
    if (spansDays && occursOn(day)) {
      return 0;
    }
    return startMinutes ?? 24 * 60 + 1;
  }

  String displayStartLabel(DateTime day) {
    if (start != null && isStartDay(day)) {
      return timeLabel(startMinutes!);
    }
    if (spansDays && occursOn(day)) {
      return '12:00 AM';
    }
    return startMinutes != null ? timeLabel(startMinutes!) : 'Any';
  }

  String displayTimeRangeLabel(DateTime day) {
    if (start == null || end == null || !occursOn(day)) {
      return '';
    }
    if (spansDays) {
      if (isStartDay(day)) {
        return '${timeLabel(startMinutes!)} – Continues';
      }
      if (isEndDay(day)) {
        return '12:00 AM – ${timeLabel(endMinutes!)}';
      }
      return 'All day';
    }
    return '${timeLabel(startMinutes!)} – ${timeLabel(endMinutes!)}';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'location': location?.toJson(),
    'notes': notes,
    'category': category.name,
    'day': _dateOnly(day).toIso8601String(),
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'cost': cost,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'reminderLeadMinutes': reminderLeadMinutes,
    'flightCode': flightCode,
    'airlineName': airlineName,
    'arrivalLocation': arrivalLocation?.toJson(),
    'departureCode': departureCode,
    'arrivalCode': arrivalCode,
  };

  factory ItineraryItem.fromJson(Map<String, dynamic> j) {
    final day = DateTime.parse(j['day'] as String);

    // Location: structured Place now, plain string in older data.
    Place? location;
    final rawLoc = j['location'];
    if (rawLoc is Map<String, dynamic>) {
      location = Place.fromJson(rawLoc);
    } else if (rawLoc is String && rawLoc.isNotEmpty) {
      location = Place(city: rawLoc);
    }

    // Times: full datetimes now; older data stored minutes-from-midnight.
    DateTime? start = j['start'] != null
        ? DateTime.parse(j['start'] as String)
        : null;
    DateTime? end = j['end'] != null
        ? DateTime.parse(j['end'] as String)
        : null;
    if (start == null && j['startMinutes'] is int) {
      final m = j['startMinutes'] as int;
      start = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
    }
    if (end == null && j['endMinutes'] is int) {
      final m = j['endMinutes'] as int;
      end = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
    }

    return ItineraryItem(
      id: j['id'] as String,
      title: j['title'] as String,
      location: location,
      notes: (j['notes'] ?? '') as String,
      category: categoryFromName((j['category'] ?? 'activity') as String),
      day: day,
      start: start,
      end: end,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      attachments: ((j['attachments'] ?? []) as List)
          .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      reminderLeadMinutes: (j['reminderLeadMinutes'] as num?)?.toInt(),
      flightCode: j['flightCode'] as String?,
      airlineName: j['airlineName'] as String?,
      arrivalLocation: j['arrivalLocation'] is Map<String, dynamic>
          ? Place.fromJson(j['arrivalLocation'] as Map<String, dynamic>)
          : null,
      departureCode: j['departureCode'] as String?,
      arrivalCode: j['arrivalCode'] as String?,
    );
  }
}
