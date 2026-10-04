import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/app_user.dart';

/// Identity, plus the profile document that mirrors it.
class AuthRepository {
  AuthRepository({required this._auth, required this._firestore});

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) {
    return guardFirebase(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  /// Creates the account and its profile document.
  ///
  /// Writing /users/{uid} is what fires `onUserCreated`, which fills in the
  /// remaining defaults and the private settings document.
  Future<void> createAccount({
    required String email,
    required String password,
    String? displayName,
  }) {
    return guardFirebase(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const UnexpectedException('Account created without a user.');
      }

      if (displayName != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
      }

      await _profileRef(user.uid).set(
        AppUser(
          id: user.uid,
          displayName: displayName ?? user.displayName,
          email: user.email,
        ).toCreateJson(),
      );
    });
  }

  /// Creates the profile document if it is missing.
  ///
  /// Needed for accounts that predate the profile document, and for providers
  /// where sign-up and first sign-in are the same event.
  Future<void> ensureProfileExists() {
    return guardFirebase(() async {
      final user = _auth.currentUser;
      if (user == null) {
        throw const UnauthenticatedException();
      }

      final ref = _profileRef(user.uid);
      if ((await ref.get()).exists) {
        return;
      }

      await ref.set(
        AppUser(
          id: user.uid,
          displayName: user.displayName,
          email: user.email,
        ).toCreateJson(),
      );
    });
  }

  Stream<AppUser?> watchProfile() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(null);
    }
    return _profileRef(uid).snapshots().map(
      (snapshot) => snapshot.exists ? AppUser.fromFirestore(snapshot) : null,
    );
  }

  Future<void> updateProfile(AppUser user) {
    return guardFirebase(
      () => _profileRef(user.id).set(user.toUpdateJson(), SetOptions(merge: true)),
    );
  }

  Future<void> sendPasswordReset(String email) {
    return guardFirebase(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  Future<void> signOut() => guardFirebase(() => _auth.signOut());

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _firestore.collection('users').doc(uid);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);

/// The signed-in user's profile document, or null when signed out.
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  // Re-subscribe when identity changes, so the stream never outlives a session.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).watchProfile();
});
