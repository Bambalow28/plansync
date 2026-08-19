import '../models/place.dart';

/// A place an advisor has spent real time in, shown on their profile.
class AdvisorPlace {
  final String city;
  final String country;
  final String countryCode;

  /// The year they were last there — the list reads newest first.
  final int year;

  /// One line in their own voice about what they know there.
  final String note;

  const AdvisorPlace({
    required this.city,
    required this.country,
    required this.countryCode,
    required this.year,
    required this.note,
  });

  String get photoQuery => '$city $country travel';
  String get label => '$city, $country';
}

/// A curated human travel advisor.
///
/// ponytail: no payments yet — [pricePerPlan] is what an advisor asks for,
/// not something the app can charge. Backed by Firestore via
/// [AdvisorDirectoryService] for the public roster and [AdvisorWorkspace] for
/// an advisor's own record.
class Advisor {
  final String id;
  final String name;

  /// Where they specialise. Null means all-around — no single city.
  final Place? city;

  final String headline;
  final String bio;

  final double rating;
  final int reviews;

  /// Price for a full custom plan, in USD. Zero means they take requests free.
  final int pricePerPlan;

  final int tripsPlanned;
  final int yearsExperience;
  final List<String> languages;
  final List<AdvisorPlace> places;

  const Advisor({
    required this.id,
    required this.name,
    required this.city,
    required this.headline,
    required this.bio,
    required this.rating,
    required this.reviews,
    required this.pricePerPlan,
    required this.tripsPlanned,
    required this.yearsExperience,
    required this.languages,
    required this.places,
  });

  bool get isAllAround => city == null;
  bool get isFree => pricePerPlan == 0;

  /// "Kyoto, Japan" or "All-around".
  String get expertiseLabel => city?.label ?? 'All-around';

  /// Initials for the monogram avatar — no stock headshots standing in for
  /// people who don't exist yet.
  String get initials {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters1;
    return '${parts.first.characters1}${parts.last.characters1}';
  }

  /// Backdrop for their profile hero.
  String get photoQuery =>
      city != null ? '${city!.city} ${city!.country} travel' : 'world travel landscape';
}

extension on String {
  String get characters1 => isEmpty ? '' : substring(0, 1).toUpperCase();
}
