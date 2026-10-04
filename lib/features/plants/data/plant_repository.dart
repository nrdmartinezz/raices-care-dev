import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/plant.dart';

/// The plants one user owns.
class PlantRepository {
  PlantRepository({required this._firestore, required this._userId});

  final FirebaseFirestore _firestore;
  final String? _userId;

  static const _uuid = Uuid();

  /// Active plants, alphabetically. Backed by the
  /// `status.isArchived, displayName` composite index.
  Stream<List<Plant>> watchActivePlants() {
    return _plants
        .where('status.isArchived', isEqualTo: false)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Plant.fromFirestore).toList());
  }

  Stream<List<Plant>> watchPlantsInGarden(String gardenId) {
    return _plants
        .where('gardenId', isEqualTo: gardenId)
        .where('status.isArchived', isEqualTo: false)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Plant.fromFirestore).toList());
  }

  Stream<Plant?> watchPlant(String plantId) {
    return _plants
        .doc(plantId)
        .snapshots()
        .map((snapshot) => snapshot.exists ? Plant.fromFirestore(snapshot) : null);
  }

  Future<Plant?> getPlant(String plantId) {
    return guardFirebase(() async {
      final snapshot = await _plants.doc(plantId).get();
      return snapshot.exists ? Plant.fromFirestore(snapshot) : null;
    });
  }

  /// Creates a plant and returns its id.
  ///
  /// The id is generated here rather than by Firestore so the caller can
  /// reference the plant immediately. Reminders are seeded asynchronously by
  /// `onPlantCreated`, so expect them to appear a moment later.
  Future<String> createPlant(Plant plant) {
    return guardFirebase(() async {
      final id = plant.id.isEmpty ? _uuid.v4() : plant.id;
      await _plants.doc(id).set(plant.toCreateJson());
      return id;
    });
  }

  Future<void> updatePlant(Plant plant) {
    return guardFirebase(
      () => _plants.doc(plant.id).set(plant.toUpdateJson(), SetOptions(merge: true)),
    );
  }

  /// Archives rather than deletes, so the care history stays intact.
  Future<void> archivePlant(String plantId) {
    return guardFirebase(
      () => _plants.doc(plantId).update({
        'status.isArchived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Permanently removes the plant document.
  ///
  /// Firestore does not cascade: the careEvents, photos and observations
  /// subcollections survive, as do the plant's reminders. Deleting those
  /// belongs in a Cloud Function so one failure cannot leave orphans.
  Future<void> deletePlant(String plantId) {
    return guardFirebase(() => _plants.doc(plantId).delete());
  }

  CollectionReference<Map<String, dynamic>> get _plants {
    final uid = _userId;
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return _firestore.collection('users').doc(uid).collection('plants');
  }
}

final plantRepositoryProvider = Provider<PlantRepository>(
  (ref) => PlantRepository(
    firestore: ref.watch(firestoreProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);

final activePlantsProvider = StreamProvider<List<Plant>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(plantRepositoryProvider).watchActivePlants();
});

/// One plant, watched rather than fetched: `onPlantCreated` fills in the
/// care fields a moment after the document appears, and the profile should
/// show them as they land.
final plantProvider = StreamProvider.family<Plant?, String>((ref, plantId) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(null);
  }
  return ref.watch(plantRepositoryProvider).watchPlant(plantId);
});
