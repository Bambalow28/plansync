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
/// ponytail: static dummy roster — there is no backend, no accounts, and no
/// payments yet. Rates and ratings are illustrative, not real offers. Replace
/// this file with a fetched feed when the marketplace gets a server; the UI
/// reads only the fields below, so nothing above it needs to change.
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

const List<Advisor> kAdvisors = [
  Advisor(
    id: 'a-mika',
    name: 'Mika Tanaka',
    city: Place(city: 'Kyoto', country: 'Japan', countryCode: 'JP'),
    headline: 'Temples, tea houses, and the quiet hours',
    bio:
        'I grew up three streets from the Kamo river and have spent fifteen years '
        'showing people the Kyoto that exists before the tour buses arrive. My plans '
        'are built around light and timing — which garden at dawn, which alley at '
        'dusk, and where to eat when everything closes at nine.',
    rating: 4.9,
    reviews: 214,
    pricePerPlan: 140,
    tripsPlanned: 380,
    yearsExperience: 15,
    languages: ['Japanese', 'English'],
    places: [
      AdvisorPlace(
        city: 'Kyoto',
        country: 'Japan',
        countryCode: 'JP',
        year: 2026,
        note: 'Home. I still find a new tea house every season.',
      ),
      AdvisorPlace(
        city: 'Kanazawa',
        country: 'Japan',
        countryCode: 'JP',
        year: 2025,
        note: 'The garden here rivals anything in Kyoto, with a fraction of the crowd.',
      ),
      AdvisorPlace(
        city: 'Seoul',
        country: 'South Korea',
        countryCode: 'KR',
        year: 2024,
        note: 'Three weeks eating my way through Euljiro after midnight.',
      ),
      AdvisorPlace(
        city: 'Taipei',
        country: 'Taiwan',
        countryCode: 'TW',
        year: 2023,
        note: 'Went for the tea mountains, stayed for the bookshops.',
      ),
    ],
  ),
  Advisor(
    id: 'a-diego',
    name: 'Diego Ramírez',
    city: Place(city: 'Mexico City', country: 'Mexico', countryCode: 'MX'),
    headline: 'Markets, murals, and the case against a rushed itinerary',
    bio:
        'Former chef, current guide. I plan trips around the table — which market on '
        'which morning, whose kitchen is worth the taxi, and how to spend an afternoon '
        'in Coyoacán without checking your phone. Expect fewer stops than you asked '
        'for and more time at each one.',
    rating: 4.8,
    reviews: 167,
    pricePerPlan: 95,
    tripsPlanned: 240,
    yearsExperience: 9,
    languages: ['Spanish', 'English'],
    places: [
      AdvisorPlace(
        city: 'Mexico City',
        country: 'Mexico',
        countryCode: 'MX',
        year: 2026,
        note: 'Twelve years here and Sunday at Mercado de Medellín never gets old.',
      ),
      AdvisorPlace(
        city: 'Oaxaca',
        country: 'Mexico',
        countryCode: 'MX',
        year: 2025,
        note: 'Mole country. Go in October, thank me in November.',
      ),
      AdvisorPlace(
        city: 'Lima',
        country: 'Peru',
        countryCode: 'PE',
        year: 2024,
        note: 'Cooked a season in Barranco. The ceviche is the least of it.',
      ),
      AdvisorPlace(
        city: 'Barcelona',
        country: 'Spain',
        countryCode: 'ES',
        year: 2022,
        note: 'Staged in a Gràcia kitchen and learned to eat dinner at eleven.',
      ),
    ],
  ),
  Advisor(
    id: 'a-amara',
    name: 'Amara Okonkwo',
    city: null,
    headline: 'Long routes, many borders, one carry-on',
    bio:
        'I plan the trips that do not fit in one city. Six countries in five weeks, '
        'overland where it is worth it and flown where it is not. If you have a start '
        'date, an end date, and a vague sense of a continent, that is enough for me '
        'to work with.',
    rating: 4.7,
    reviews: 302,
    pricePerPlan: 180,
    tripsPlanned: 510,
    yearsExperience: 12,
    languages: ['English', 'French', 'Portuguese'],
    places: [
      AdvisorPlace(
        city: 'Cape Town',
        country: 'South Africa',
        countryCode: 'ZA',
        year: 2026,
        note: 'The only city I have flown to twice in one year by accident.',
      ),
      AdvisorPlace(
        city: 'Marrakesh',
        country: 'Morocco',
        countryCode: 'MA',
        year: 2025,
        note: 'Base yourself in a riad, not a hotel. It changes the whole trip.',
      ),
      AdvisorPlace(
        city: 'Lisbon',
        country: 'Portugal',
        countryCode: 'PT',
        year: 2025,
        note: 'My reset city between long routes.',
      ),
      AdvisorPlace(
        city: 'Istanbul',
        country: 'Turkey',
        countryCode: 'TR',
        year: 2024,
        note: 'Two continents, one ferry ticket, endless breakfast.',
      ),
      AdvisorPlace(
        city: 'Hanoi',
        country: 'Vietnam',
        countryCode: 'VN',
        year: 2023,
        note: 'Start of a six-week overland run to Singapore.',
      ),
    ],
  ),
  Advisor(
    id: 'a-sofia',
    name: 'Sofia Bergström',
    city: Place(city: 'Reykjavík', country: 'Iceland', countryCode: 'IS'),
    headline: 'Weather, roads, and where the light actually is',
    bio:
        'I plan Iceland around two things most itineraries ignore: the forecast and '
        'the road closures. Photographers and first-timers both end up with the same '
        'advice from me — go slower, drive less, and keep two days unbooked so you '
        'can chase a clear sky when it appears.',
    rating: 5.0,
    reviews: 88,
    pricePerPlan: 0,
    tripsPlanned: 130,
    yearsExperience: 7,
    languages: ['Icelandic', 'Swedish', 'English'],
    places: [
      AdvisorPlace(
        city: 'Reykjavík',
        country: 'Iceland',
        countryCode: 'IS',
        year: 2026,
        note: 'Base camp. Everything else is a day trip from here.',
      ),
      AdvisorPlace(
        city: 'Tromsø',
        country: 'Norway',
        countryCode: 'NO',
        year: 2025,
        note: 'For when Iceland is clouded in and the lights are north instead.',
      ),
      AdvisorPlace(
        city: 'Nuuk',
        country: 'Greenland',
        countryCode: 'GL',
        year: 2024,
        note: 'Harder to reach than people think, and worth every leg of it.',
      ),
    ],
  ),
  Advisor(
    id: 'a-luca',
    name: 'Luca Ferrari',
    city: Place(city: 'Rome', country: 'Italy', countryCode: 'IT'),
    headline: 'Two thousand years, planned as a walk',
    bio:
        'Art historian by training, walker by preference. I build Rome as a series of '
        'routes rather than a checklist of sites, so the Forum arrives on foot from '
        'the right direction and lunch is never a forty-minute detour. Good for '
        'repeat visitors who think they have already seen it.',
    rating: 4.8,
    reviews: 141,
    pricePerPlan: 110,
    tripsPlanned: 195,
    yearsExperience: 11,
    languages: ['Italian', 'English', 'French'],
    places: [
      AdvisorPlace(
        city: 'Rome',
        country: 'Italy',
        countryCode: 'IT',
        year: 2026,
        note: 'Born here. Still walk a new street every week.',
      ),
      AdvisorPlace(
        city: 'Naples',
        country: 'Italy',
        countryCode: 'IT',
        year: 2025,
        note: 'The correct day trip. Not Florence.',
      ),
      AdvisorPlace(
        city: 'Athens',
        country: 'Greece',
        countryCode: 'GR',
        year: 2024,
        note: 'Pair it with Rome and the whole classical world clicks into place.',
      ),
    ],
  ),
];
