import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/advisors.dart';
import '../models/place.dart';

/// Where an advisor application currently stands.
enum AdvisorStatus {
  /// Never applied — the top-right button invites them to.
  none,

  /// Submitted and waiting on the owner's decision.
  pending,

  /// Approved by the owner; the dashboard is theirs.
  approved,
}

/// What a traveller asked an advisor to plan.
enum RequestState { pending, accepted, declined }

class PlanRequest {
  final String id;
  final String travellerName;
  final Place destination;
  final DateTime start;
  final DateTime end;
  final int partySize;
  final int budget;
  final String currency;
  final String message;

  /// Days ago the request came in — fixed offsets rather than stored dates so
  /// the mockup never shows a request from the future.
  final int daysAgo;

  RequestState state;

  PlanRequest({
    required this.id,
    required this.travellerName,
    required this.destination,
    required this.start,
    required this.end,
    required this.partySize,
    required this.budget,
    required this.currency,
    required this.message,
    required this.daysAgo,
    this.state = RequestState.pending,
  });

  int get nights => end.difference(start).inDays;
}

/// A place on the advisor's own travel list, with the switch that decides
/// whether travellers see it.
class MyPlace {
  final String city;
  final String country;
  final String countryCode;
  final int year;
  String note;
  bool shown;

  MyPlace({
    required this.city,
    required this.country,
    required this.countryCode,
    required this.year,
    required this.note,
    this.shown = true,
  });

  AdvisorPlace toAdvisorPlace() => AdvisorPlace(
    city: city,
    country: country,
    countryCode: countryCode,
    year: year,
    note: note,
  );

  String get label => '$city, $country';
}

/// The signed-in advisor's own editable record.
///
/// ponytail: mockup state. Everything but [AdvisorStatus] lives in memory for
/// the session — edits feel real while you are in the app and reset on
/// relaunch. There is no backend, no account, and no owner-review pipeline to
/// persist any of this to; wiring those is the next piece of work, not this
/// one.
class AdvisorWorkspace extends ChangeNotifier {
  AdvisorWorkspace._();
  static final AdvisorWorkspace instance = AdvisorWorkspace._();

  static const _statusKey = 'advisor_status_v1';

  AdvisorStatus _status = AdvisorStatus.none;
  AdvisorStatus get status => _status;

  // Seeded so an approved advisor has something to edit rather than an empty
  // shell — the mockup is about the shape of the work, not data entry.
  String name = 'Alex Rivera';
  Place? city = const Place(city: 'Lisbon', country: 'Portugal', countryCode: 'PT');
  String headline = 'Tiled streets, long lunches, and the Atlantic light';
  String bio =
      'I moved to Lisbon nine years ago for a six-month contract and never left. '
      'I plan trips that follow the light — which miradouro at which hour, where '
      'to eat when the tourist places close, and the day trip that is worth the '
      'train.';
  List<String> languages = ['Portuguese', 'English', 'Spanish'];
  int pricePerPlan = 120;
  int yearsExperience = 9;

  final List<MyPlace> places = [
    MyPlace(
      city: 'Lisbon',
      country: 'Portugal',
      countryCode: 'PT',
      year: 2026,
      note: 'Home. Still walking a new street most weeks.',
    ),
    MyPlace(
      city: 'Porto',
      country: 'Portugal',
      countryCode: 'PT',
      year: 2025,
      note: 'The right overnight trip, not a rushed day trip.',
    ),
    MyPlace(
      city: 'Seville',
      country: 'Spain',
      countryCode: 'ES',
      year: 2025,
      note: 'Go in spring or not at all.',
    ),
    MyPlace(
      city: 'Tangier',
      country: 'Morocco',
      countryCode: 'MA',
      year: 2024,
      note: 'A ferry and a different continent by lunchtime.',
      shown: false,
    ),
    MyPlace(
      city: 'Madeira',
      country: 'Portugal',
      countryCode: 'PT',
      year: 2023,
      note: 'Levada walks, and the only place I have been rained on happily.',
      shown: false,
    ),
  ];

  final List<PlanRequest> requests = [
    PlanRequest(
      id: 'r1',
      travellerName: 'Priya Nair',
      destination: const Place(city: 'Lisbon', country: 'Portugal', countryCode: 'PT'),
      start: DateTime(2026, 9, 12),
      end: DateTime(2026, 9, 19),
      partySize: 2,
      budget: 3200,
      currency: 'EUR',
      message:
          'First time in Portugal, travelling with my partner. We would rather '
          'eat well and walk a lot than tick off sights. Is a day in Sintra '
          'worth it or is that a trap?',
      daysAgo: 1,
    ),
    PlanRequest(
      id: 'r2',
      travellerName: 'Tom Whitfield',
      destination: const Place(city: 'Porto', country: 'Portugal', countryCode: 'PT'),
      start: DateTime(2026, 10, 3),
      end: DateTime(2026, 10, 7),
      partySize: 4,
      budget: 2600,
      currency: 'EUR',
      message:
          'Four of us, all mid-thirties, going for my brother\'s birthday. We '
          'want one really good dinner and otherwise something loose.',
      daysAgo: 3,
    ),
    PlanRequest(
      id: 'r3',
      travellerName: 'Marta Kowalski',
      destination: const Place(city: 'Lisbon', country: 'Portugal', countryCode: 'PT'),
      start: DateTime(2026, 11, 20),
      end: DateTime(2026, 11, 27),
      partySize: 1,
      budget: 1800,
      currency: 'EUR',
      message:
          'Solo, working remotely in the mornings. I need somewhere to be that '
          'is not my hotel room, and a reason to leave the city on the weekend.',
      daysAgo: 6,
      state: RequestState.accepted,
    ),
  ];

  int get pendingRequestCount =>
      requests.where((r) => r.state == RequestState.pending).length;

  List<MyPlace> get shownPlaces => [
    for (final p in places)
      if (p.shown) p,
  ];

  /// Reads the saved application status. Called from `main()`.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_statusKey);
      _status = AdvisorStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => AdvisorStatus.none,
      );
    } catch (e) {
      debugPrint('Advisor status load failed: $e');
    }
  }

  Future<void> setStatus(AdvisorStatus status) async {
    _status = status;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_statusKey, status.name);
    } catch (e) {
      debugPrint('Advisor status save failed: $e');
    }
  }

  void updateProfile({
    String? headline,
    String? bio,
    int? pricePerPlan,
    List<String>? languages,
    Place? city,
  }) {
    if (headline != null) this.headline = headline;
    if (bio != null) this.bio = bio;
    if (pricePerPlan != null) this.pricePerPlan = pricePerPlan;
    if (languages != null) this.languages = languages;
    if (city != null) this.city = city;
    notifyListeners();
  }

  void togglePlace(MyPlace place, bool shown) {
    place.shown = shown;
    notifyListeners();
  }

  void setRequestState(PlanRequest request, RequestState state) {
    request.state = state;
    notifyListeners();
  }

  /// The public-facing record travellers would see — lets the dashboard preview
  /// reuse the real profile screen rather than approximating it.
  Advisor toPublicAdvisor() => Advisor(
    id: 'me',
    name: name,
    city: city,
    headline: headline,
    bio: bio,
    rating: 4.9,
    reviews: 36,
    pricePerPlan: pricePerPlan,
    tripsPlanned: 48,
    yearsExperience: yearsExperience,
    languages: languages,
    places: [for (final p in shownPlaces) p.toAdvisorPlace()],
  );
}
