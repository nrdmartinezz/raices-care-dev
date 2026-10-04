import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/observation.dart';

/// The notes kept against one user's plants.
///
/// Unlike care events, nothing server-side reacts to an observation: it is the
/// gardener's own record, so it is written and read straight from Firestore.
class ObservationRepository {
  ObservationRepository({required this._firestore, required this._userId});

  final FirebaseFirestore _firestore;
  final String? _userId;

  /// Newest first, which is the order the plant journal reads in.
  Stream<List<Observation>> watchForPlant(String plantId, {int limit = 20}) {
    return _observations(plantId)
        .orderBy('observedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Observation.fromFirestore).toList(),
        );
  }

  Future<void> add({required String plantId, required String note}) {
    final entry = note.trim();
    if (entry.isEmpty) {
      throw const MalformedDataException('Write a note first.');
    }
    return guardFirebase(
      () => _observations(plantId).add(
        Observation(
          id: '',
          note: entry.length > Observation.noteLimit
              ? entry.substring(0, Observation.noteLimit)
              : entry,
          observedAt: DateTime.now(),
        ).toCreateJson(),
      ),
    );
  }

  Future<void> delete({
    required String plantId,
    required String observationId,
  }) {
    return guardFirebase(
      () => _observations(plantId).doc(observationId).delete(),
    );
  }

  CollectionReference<Map<String, dynamic>> _observations(String plantId) {
    final uid = _userId;
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('plants')
        .doc(plantId)
        .collection('observations');
  }
}

final observationRepositoryProvider = Provider<ObservationRepository>(
  (ref) => ObservationRepository(
    firestore: ref.watch(firestoreProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);

final plantObservationsProvider =
    StreamProvider.family<List<Observation>, String>((ref, plantId) {
      if (ref.watch(currentUserIdProvider) == null) {
        return Stream.value(const []);
      }
      return ref.watch(observationRepositoryProvider).watchForPlant(plantId);
    });
