import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place.dart';
import 'advisor_workspace.dart' show RequestState;

/// Sends a traveller's plan request to an advisor.
class PlanRequestService {
  PlanRequestService._();
  static final PlanRequestService instance = PlanRequestService._();

  Future<void> submit({
    required String advisorId,
    required Place destination,
    required DateTime start,
    required DateTime end,
    required int partySize,
    required int budget,
    required String currency,
    required String message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to request a plan.');
    }
    final travellerName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : (user.email ?? 'Traveller');
    await FirebaseFirestore.instance.collection('requests').add({
      'travellerId': user.uid,
      'advisorId': advisorId,
      'travellerName': travellerName,
      'destination': destination.toJson(),
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'partySize': partySize,
      'budget': budget,
      'currency': currency,
      'message': message,
      'state': RequestState.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
