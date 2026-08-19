import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/advisors.dart';
import '../models/place.dart';

/// Reads the public roster of approved advisors straight from Firestore.
///
/// ponytail: one extra read per advisor for their shown places (N+1) instead
/// of denormalizing places onto the advisor doc — fine at the roster sizes
/// this app has today. Revisit if the roster grows large enough to matter.
class AdvisorDirectoryService {
  AdvisorDirectoryService._();
  static final AdvisorDirectoryService instance = AdvisorDirectoryService._();

  Future<List<Advisor>> fetchApproved() async {
    final snap = await FirebaseFirestore.instance
        .collection('advisors')
        .where('status', isEqualTo: 'approved')
        .get();
    return Future.wait(snap.docs.map(_toAdvisor));
  }

  Future<Advisor> _toAdvisor(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final placesSnap = await doc.reference
        .collection('places')
        .where('shown', isEqualTo: true)
        .get();
    final places = placesSnap.docs.map((p) {
      final pd = p.data();
      return AdvisorPlace(
        city: (pd['city'] ?? '') as String,
        country: (pd['country'] ?? '') as String,
        countryCode: (pd['countryCode'] ?? '') as String,
        year: (pd['year'] as num?)?.toInt() ?? DateTime.now().year,
        note: (pd['note'] ?? '') as String,
      );
    }).toList()
      ..sort((a, b) => b.year.compareTo(a.year));

    final cityData = d['city'];
    final allAround = d['allAround'] == true;

    return Advisor(
      id: doc.id,
      name: (d['name'] ?? '') as String,
      city: !allAround && cityData is Map ? Place.fromJson(cityData.cast<String, dynamic>()) : null,
      headline: (d['headline'] ?? '') as String,
      bio: (d['bio'] ?? '') as String,
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      reviews: (d['reviewsCount'] as num?)?.toInt() ?? 0,
      pricePerPlan: (d['pricePerPlan'] as num?)?.toInt() ?? 0,
      tripsPlanned: (d['tripsPlanned'] as num?)?.toInt() ?? 0,
      yearsExperience: (d['yearsExperience'] as num?)?.toInt() ?? 0,
      languages: (d['languages'] as List?)?.cast<String>() ?? const [],
      places: places,
    );
  }
}
