import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  final String travellerId;
  final String advisorId;
  final String travellerName;
  final Place destination;
  final DateTime start;
  final DateTime end;
  final int partySize;
  final int budget;
  final String currency;
  final String message;
  final DateTime createdAt;

  RequestState state;

  PlanRequest({
    required this.id,
    required this.travellerId,
    required this.advisorId,
    required this.travellerName,
    required this.destination,
    required this.start,
    required this.end,
    required this.partySize,
    required this.budget,
    required this.currency,
    required this.message,
    required this.createdAt,
    this.state = RequestState.pending,
  });

  int get nights => end.difference(start).inDays;
  int get daysAgo => DateTime.now().difference(createdAt).inDays;

  factory PlanRequest.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PlanRequest(
      id: doc.id,
      travellerId: (d['travellerId'] ?? '') as String,
      advisorId: (d['advisorId'] ?? '') as String,
      travellerName: (d['travellerName'] ?? '') as String,
      destination: Place.fromJson((d['destination'] as Map?)?.cast<String, dynamic>() ?? const {}),
      start: (d['start'] as Timestamp).toDate(),
      end: (d['end'] as Timestamp).toDate(),
      partySize: (d['partySize'] as num?)?.toInt() ?? 1,
      budget: (d['budget'] as num?)?.toInt() ?? 0,
      currency: (d['currency'] ?? 'USD') as String,
      message: (d['message'] ?? '') as String,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      state: RequestState.values.firstWhere(
        (s) => s.name == d['state'],
        orElse: () => RequestState.pending,
      ),
    );
  }
}

/// A place on the advisor's own travel list, with the switch that decides
/// whether travellers see it.
class MyPlace {
  final String id;
  final String city;
  final String country;
  final String countryCode;
  final int year;
  String note;
  bool shown;

  MyPlace({
    required this.id,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.year,
    required this.note,
    this.shown = true,
  });

  factory MyPlace.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return MyPlace(
      id: doc.id,
      city: (d['city'] ?? '') as String,
      country: (d['country'] ?? '') as String,
      countryCode: (d['countryCode'] ?? '') as String,
      year: (d['year'] as num?)?.toInt() ?? DateTime.now().year,
      note: (d['note'] ?? '') as String,
      shown: (d['shown'] as bool?) ?? true,
    );
  }

  AdvisorPlace toAdvisorPlace() => AdvisorPlace(
    city: city,
    country: country,
    countryCode: countryCode,
    year: year,
    note: note,
  );

  String get label => '$city, $country';
}

/// The signed-in advisor's own editable record, backed by Firestore.
///
/// `advisors/{uid}` holds [status] and the profile fields; `advisors/{uid}/
/// places` holds [places]; `requests` (queried by `advisorId`) holds
/// [requests]. All three are live snapshots — an edit elsewhere (or by the
/// owner, for [status]) shows up here without a reload.
///
/// ponytail: no owner-review pipeline yet — applications are approved by hand
/// in the Firebase console, not through the app.
class AdvisorWorkspace extends ChangeNotifier {
  AdvisorWorkspace._();
  static final AdvisorWorkspace instance = AdvisorWorkspace._();

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _placesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSub;

  AdvisorStatus _status = AdvisorStatus.none;
  AdvisorStatus get status => _status;

  String name = '';
  Place? city;
  String headline = '';
  String bio = '';
  List<String> languages = [];
  int pricePerPlan = 0;
  int yearsExperience = 0;
  double rating = 0;
  int reviewsCount = 0;
  int tripsPlanned = 0;

  List<MyPlace> places = [];
  List<PlanRequest> requests = [];

  int get pendingRequestCount =>
      requests.where((r) => r.state == RequestState.pending).length;

  List<MyPlace> get shownPlaces => [
    for (final p in places)
      if (p.shown) p,
  ];

  CollectionReference<Map<String, dynamic>> get _advisors =>
      FirebaseFirestore.instance.collection('advisors');

  /// Starts following the signed-in user's advisor doc, places, and requests.
  /// Called from `main()`; keeps listening across sign-in/out.
  Future<void> load() async {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _docSub?.cancel();
    _placesSub?.cancel();
    _requestsSub?.cancel();
    if (user == null) {
      _status = AdvisorStatus.none;
      places = [];
      requests = [];
      notifyListeners();
      return;
    }

    final ref = _advisors.doc(user.uid);
    _docSub = ref.snapshots().listen((doc) {
      final data = doc.data();
      _status = AdvisorStatus.values.firstWhere(
        (s) => s.name == data?['status'],
        orElse: () => AdvisorStatus.none,
      );
      if (data != null) {
        name = (data['name'] as String?) ?? name;
        headline = (data['headline'] as String?) ?? headline;
        bio = (data['bio'] as String?) ?? bio;
        pricePerPlan = (data['pricePerPlan'] as num?)?.toInt() ?? pricePerPlan;
        yearsExperience = (data['yearsExperience'] as num?)?.toInt() ?? yearsExperience;
        rating = (data['rating'] as num?)?.toDouble() ?? rating;
        reviewsCount = (data['reviewsCount'] as num?)?.toInt() ?? reviewsCount;
        tripsPlanned = (data['tripsPlanned'] as num?)?.toInt() ?? tripsPlanned;
        final rawLanguages = data['languages'];
        if (rawLanguages is List) languages = rawLanguages.cast<String>();
        final cityData = data['city'];
        if (cityData is Map) city = Place.fromJson(cityData.cast<String, dynamic>());
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Advisor doc stream failed: $e'));

    _placesSub = ref.collection('places').snapshots().listen((snap) {
      places = snap.docs.map(MyPlace.fromDoc).toList()
        ..sort((a, b) => b.year.compareTo(a.year));
      notifyListeners();
    }, onError: (e) => debugPrint('Advisor places stream failed: $e'));

    _requestsSub = FirebaseFirestore.instance
        .collection('requests')
        .where('advisorId', isEqualTo: user.uid)
        .snapshots()
        .listen((snap) {
      requests = snap.docs.map(PlanRequest.fromDoc).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }, onError: (e) => debugPrint('Advisor requests stream failed: $e'));
  }

  /// Writes an application to `advisors/{uid}`, moving [status] to pending.
  /// Throws if nobody is signed in — callers must gate on [AuthService].
  Future<void> submitApplication({
    required String name,
    required String email,
    required String headline,
    required String bio,
    Place? city,
    required bool allAround,
    int? yearsExperience,
    int? pricePerPlan,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Must be signed in to apply as an advisor.');
    }
    await _advisors.doc(uid).set({
      'status': AdvisorStatus.pending.name,
      'name': name,
      'email': email,
      'headline': headline,
      'bio': bio,
      'city': city?.toJson(),
      'allAround': allAround,
      'yearsExperience': yearsExperience,
      'pricePerPlan': pricePerPlan,
      'submittedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Local-only edit, for the profile editor's live preview — call
  /// [persistProfile] to actually save it.
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

  /// Saves the current in-memory profile fields to `advisors/{uid}`.
  Future<void> persistProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _advisors.doc(uid).set({
      'headline': headline,
      'bio': bio,
      'pricePerPlan': pricePerPlan,
      'languages': languages,
      'city': city?.toJson(),
    }, SetOptions(merge: true));
  }

  Future<void> addPlace({
    required String city,
    required String country,
    required String countryCode,
    required int year,
    required String note,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _advisors.doc(uid).collection('places').add({
      'city': city,
      'country': country,
      'countryCode': countryCode,
      'year': year,
      'note': note,
      'shown': true,
    });
  }

  Future<void> togglePlace(MyPlace place, bool shown) async {
    place.shown = shown;
    notifyListeners();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _advisors.doc(uid).collection('places').doc(place.id).update({'shown': shown});
  }

  Future<void> setRequestState(PlanRequest request, RequestState state) async {
    request.state = state;
    notifyListeners();
    await FirebaseFirestore.instance
        .collection('requests')
        .doc(request.id)
        .update({'state': state.name});
  }

  /// The public-facing record travellers would see — lets the dashboard preview
  /// reuse the real profile screen rather than approximating it.
  Advisor toPublicAdvisor() => Advisor(
    id: 'me',
    name: name,
    city: city,
    headline: headline,
    bio: bio,
    rating: rating,
    reviews: reviewsCount,
    pricePerPlan: pricePerPlan,
    tripsPlanned: tripsPlanned,
    yearsExperience: yearsExperience,
    languages: languages,
    places: [for (final p in shownPlaces) p.toAdvisorPlace()],
  );

  @override
  void dispose() {
    _authSub?.cancel();
    _docSub?.cancel();
    _placesSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
