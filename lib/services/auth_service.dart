import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Auth — the one place the rest of the app
/// touches sign-in/out, so a second provider (Apple, Google) later means
/// changing this file, not every call site.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  User? get currentUser => FirebaseAuth.instance.currentUser;
  Stream<User?> get authStateChanges => FirebaseAuth.instance.authStateChanges();

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(name);
    await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn({required String email, required String password}) =>
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
