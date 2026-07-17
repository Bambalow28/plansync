/// A real place (city) chosen from the offline search dropdown. Used for a
/// trip's destination and an itinerary item's location.
class Place {
  final String city;
  final String country;
  final String countryCode;
  final double? lat;
  final double? lon;

  const Place({
    required this.city,
    this.country = '',
    this.countryCode = '',
    this.lat,
    this.lon,
  });

  /// Display label, e.g. "Tokyo, Japan".
  String get label => country.isEmpty ? city : '$city, $country';

  Map<String, dynamic> toJson() => {
        'city': city,
        'country': country,
        'countryCode': countryCode,
        'lat': lat,
        'lon': lon,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        city: (j['city'] ?? '') as String,
        country: (j['country'] ?? '') as String,
        countryCode: (j['countryCode'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is Place && other.city == city && other.country == country && other.lat == lat;

  @override
  int get hashCode => Object.hash(city, country, lat);
}
