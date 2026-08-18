import '../models/place.dart';
import '../models/trip.dart';

/// Broad buckets used to bias suggestions toward the user's part of the world.
enum Region { asia, europe, americas, africa, oceania }

/// A curated destination for the home-screen carousel.
///
/// ponytail: this is a hand-maintained list, not a real popularity signal —
/// there's no backend and no usage analytics to derive one from. [months] is
/// "when is this place at its best", not measured demand. Replace the whole
/// file with a fetched feed once creators and a backend exist.
class SuggestedPlace {
  final String city;
  final String country;
  final String countryCode;
  final Region region;

  /// Month numbers (1–12) this destination is most worth visiting.
  final List<int> months;

  /// One short line shown under the city name.
  final String tagline;

  /// Gradient shown instead of a photo when offline or unconfigured.
  final TripCover cover;

  const SuggestedPlace({
    required this.city,
    required this.country,
    required this.countryCode,
    required this.region,
    required this.months,
    required this.tagline,
    required this.cover,
  });

  Place toPlace() => Place(city: city, country: country, countryCode: countryCode);

  /// The search text used to find this destination's photo.
  String get photoQuery => '$city $country travel';
}

const List<SuggestedPlace> kSuggestedPlaces = [
  // Asia
  SuggestedPlace(
    city: 'Tokyo',
    country: 'Japan',
    countryCode: 'JP',
    region: Region.asia,
    months: [3, 4, 5, 10, 11],
    tagline: 'Cherry blossoms and neon nights',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'Kyoto',
    country: 'Japan',
    countryCode: 'JP',
    region: Region.asia,
    months: [4, 10, 11],
    tagline: 'Temples, gardens, and autumn maples',
    cover: TripCover.forest,
  ),
  SuggestedPlace(
    city: 'Bangkok',
    country: 'Thailand',
    countryCode: 'TH',
    region: Region.asia,
    months: [11, 12, 1, 2],
    tagline: 'Street food capital of the world',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'Bali',
    country: 'Indonesia',
    countryCode: 'ID',
    region: Region.asia,
    months: [4, 5, 6, 7, 8, 9],
    tagline: 'Rice terraces and volcanic coastline',
    cover: TripCover.forest,
  ),
  SuggestedPlace(
    city: 'Seoul',
    country: 'South Korea',
    countryCode: 'KR',
    region: Region.asia,
    months: [4, 5, 9, 10],
    tagline: 'Palaces, markets, and midnight food',
    cover: TripCover.violet,
  ),
  SuggestedPlace(
    city: 'Dubai',
    country: 'United Arab Emirates',
    countryCode: 'AE',
    region: Region.asia,
    months: [11, 12, 1, 2, 3],
    tagline: 'Desert dunes beside a skyline',
    cover: TripCover.sunset,
  ),
  // Europe
  SuggestedPlace(
    city: 'Lisbon',
    country: 'Portugal',
    countryCode: 'PT',
    region: Region.europe,
    months: [3, 4, 5, 9, 10],
    tagline: 'Tiled streets above the Atlantic',
    cover: TripCover.ocean,
  ),
  SuggestedPlace(
    city: 'Rome',
    country: 'Italy',
    countryCode: 'IT',
    region: Region.europe,
    months: [4, 5, 6, 9, 10],
    tagline: 'Two thousand years, one walk',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'Paris',
    country: 'France',
    countryCode: 'FR',
    region: Region.europe,
    months: [4, 5, 6, 9, 10],
    tagline: 'Long lunches and longer evenings',
    cover: TripCover.violet,
  ),
  SuggestedPlace(
    city: 'Reykjavík',
    country: 'Iceland',
    countryCode: 'IS',
    region: Region.europe,
    months: [6, 7, 8, 9, 10, 2, 3],
    tagline: 'Northern lights and black-sand coast',
    cover: TripCover.ocean,
  ),
  SuggestedPlace(
    city: 'Barcelona',
    country: 'Spain',
    countryCode: 'ES',
    region: Region.europe,
    months: [5, 6, 9, 10],
    tagline: 'Gaudí, tapas, and city beaches',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'Athens',
    country: 'Greece',
    countryCode: 'GR',
    region: Region.europe,
    months: [4, 5, 6, 9, 10],
    tagline: 'Ancient stone, island ferries',
    cover: TripCover.teal,
  ),
  // Americas
  SuggestedPlace(
    city: 'Mexico City',
    country: 'Mexico',
    countryCode: 'MX',
    region: Region.americas,
    months: [3, 4, 5, 10, 11],
    tagline: 'Museums, murals, and mezcal',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'New York',
    country: 'United States',
    countryCode: 'US',
    region: Region.americas,
    months: [5, 6, 9, 10, 12],
    tagline: 'The city that sets the pace',
    cover: TripCover.slate,
  ),
  SuggestedPlace(
    city: 'Vancouver',
    country: 'Canada',
    countryCode: 'CA',
    region: Region.americas,
    months: [6, 7, 8, 9],
    tagline: 'Mountains meeting the sea',
    cover: TripCover.forest,
  ),
  SuggestedPlace(
    city: 'Rio de Janeiro',
    country: 'Brazil',
    countryCode: 'BR',
    region: Region.americas,
    months: [12, 1, 2, 3],
    tagline: 'Beaches under the granite peaks',
    cover: TripCover.ocean,
  ),
  SuggestedPlace(
    city: 'Buenos Aires',
    country: 'Argentina',
    countryCode: 'AR',
    region: Region.americas,
    months: [10, 11, 3, 4],
    tagline: 'Tango, steak, and grand avenues',
    cover: TripCover.violet,
  ),
  SuggestedPlace(
    city: 'Cusco',
    country: 'Peru',
    countryCode: 'PE',
    region: Region.americas,
    months: [5, 6, 7, 8, 9],
    tagline: 'The gateway to Machu Picchu',
    cover: TripCover.forest,
  ),
  // Africa
  SuggestedPlace(
    city: 'Cape Town',
    country: 'South Africa',
    countryCode: 'ZA',
    region: Region.africa,
    months: [11, 12, 1, 2, 3],
    tagline: 'Table Mountain over two oceans',
    cover: TripCover.ocean,
  ),
  SuggestedPlace(
    city: 'Marrakesh',
    country: 'Morocco',
    countryCode: 'MA',
    region: Region.africa,
    months: [3, 4, 5, 10, 11],
    tagline: 'Souks, riads, and the High Atlas',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'Cairo',
    country: 'Egypt',
    countryCode: 'EG',
    region: Region.africa,
    months: [10, 11, 12, 1, 2, 3],
    tagline: 'Pyramids at the edge of the city',
    cover: TripCover.sunset,
  ),
  SuggestedPlace(
    city: 'Zanzibar City',
    country: 'Tanzania',
    countryCode: 'TZ',
    region: Region.africa,
    months: [6, 7, 8, 9, 10],
    tagline: 'Spice islands and turquoise water',
    cover: TripCover.teal,
  ),
  // Oceania
  SuggestedPlace(
    city: 'Sydney',
    country: 'Australia',
    countryCode: 'AU',
    region: Region.oceania,
    months: [10, 11, 12, 1, 2, 3],
    tagline: 'Harbour city, endless coastline',
    cover: TripCover.ocean,
  ),
  SuggestedPlace(
    city: 'Queenstown',
    country: 'New Zealand',
    countryCode: 'NZ',
    region: Region.oceania,
    months: [12, 1, 2, 6, 7, 8],
    tagline: 'Alpine lakes and every adventure',
    cover: TripCover.forest,
  ),
];

/// Region for a detected country code. Deliberately partial — it only needs to
/// cover where users actually are; anything unmapped returns null and the
/// carousel just shows the unbiased seasonal order.
const Map<String, Region> _regionByCountry = {
  // Asia
  'JP': Region.asia, 'KR': Region.asia, 'CN': Region.asia, 'TW': Region.asia,
  'HK': Region.asia, 'SG': Region.asia, 'TH': Region.asia, 'VN': Region.asia,
  'ID': Region.asia, 'MY': Region.asia, 'PH': Region.asia, 'IN': Region.asia,
  'AE': Region.asia, 'SA': Region.asia, 'IL': Region.asia, 'TR': Region.asia,
  'PK': Region.asia, 'BD': Region.asia, 'LK': Region.asia, 'NP': Region.asia,
  'QA': Region.asia, 'KW': Region.asia, 'JO': Region.asia, 'KH': Region.asia,
  // Europe
  'GB': Region.europe, 'IE': Region.europe, 'FR': Region.europe,
  'DE': Region.europe, 'ES': Region.europe, 'PT': Region.europe,
  'IT': Region.europe, 'NL': Region.europe, 'BE': Region.europe,
  'CH': Region.europe, 'AT': Region.europe, 'SE': Region.europe,
  'NO': Region.europe, 'DK': Region.europe, 'FI': Region.europe,
  'IS': Region.europe, 'PL': Region.europe, 'CZ': Region.europe,
  'HU': Region.europe, 'GR': Region.europe, 'RO': Region.europe,
  'HR': Region.europe, 'RS': Region.europe, 'UA': Region.europe,
  'RU': Region.europe, 'BG': Region.europe, 'SK': Region.europe,
  // Americas
  'US': Region.americas, 'CA': Region.americas, 'MX': Region.americas,
  'BR': Region.americas, 'AR': Region.americas, 'CL': Region.americas,
  'CO': Region.americas, 'PE': Region.americas, 'EC': Region.americas,
  'UY': Region.americas, 'CR': Region.americas, 'PA': Region.americas,
  'GT': Region.americas, 'DO': Region.americas, 'CU': Region.americas,
  'JM': Region.americas, 'BO': Region.americas, 'PY': Region.americas,
  // Africa
  'ZA': Region.africa, 'MA': Region.africa, 'EG': Region.africa,
  'KE': Region.africa, 'TZ': Region.africa, 'NG': Region.africa,
  'GH': Region.africa, 'ET': Region.africa, 'TN': Region.africa,
  'SN': Region.africa, 'UG': Region.africa, 'DZ': Region.africa,
  // Oceania
  'AU': Region.oceania, 'NZ': Region.oceania, 'FJ': Region.oceania,
  'PG': Region.oceania,
};

Region? regionForCountry(String? countryCode) =>
    countryCode == null ? null : _regionByCountry[countryCode.toUpperCase()];

/// Curated destinations ordered for [month], biased toward [region] when known.
///
/// In-season destinations come first; within each half, the user's own region
/// leads. Nothing is dropped — the full list stays swipeable either way.
List<SuggestedPlace> suggestionsFor({required int month, Region? region}) {
  int rank(SuggestedPlace p) =>
      (p.months.contains(month) ? 0 : 2) + (region != null && p.region == region ? 0 : 1);

  final ordered = [...kSuggestedPlaces];
  // Stable sort keeps the curated order inside each rank bucket.
  mergeSortByRank(ordered, rank);
  return ordered;
}

/// Stable sort by an integer rank (Dart's [List.sort] is not stable).
void mergeSortByRank(List<SuggestedPlace> list, int Function(SuggestedPlace) rank) {
  final indexed = [
    for (var i = 0; i < list.length; i++) (i, list[i]),
  ]..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  for (var i = 0; i < list.length; i++) {
    list[i] = indexed[i].$2;
  }
}
