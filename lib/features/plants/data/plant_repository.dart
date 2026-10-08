import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/worker_repositories.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/plant.dart';

/// Drops archived plants and sorts by display name.
///
/// Same order as Firestore `orderBy('displayName')`: Dart [String.compareTo]
/// and Firestore both compare UTF-16 code units.
List<Plant> activePlantsIn(Iterable<Plant> plants) {
  final active = [
    for (final plant in plants)
      if (!plant.status.isArchived) plant,
  ];
  active.sort((a, b) => a.displayName.compareTo(b.displayName));
  return active;
}

/// The plants one user owns.
class PlantRepository {
  PlantRepository({required this._firestore, required this._userId});

  final FirebaseFirestore _firestore;
  final String? _userId;

  static const _uuid = Uuid();

  /// Active plants, alphabetically.
  ///
  /// The plants subcollection is listened to as a whole and filtered here.
  /// `where('status.isArchived')` plus `orderBy('displayName')` needs a
  /// composite index; until that index exists the snapshot errors, and both
  /// My Plants and Growing Now stay blank. One person's garden is small
  /// enough to drop archived plants and sort in memory, and a plain
  /// collection listen does not need that index.
  Stream<List<Plant>> watchActivePlants() {
    return _plants.snapshots().map(
      (snapshot) => activePlantsIn(snapshot.docs.map(Plant.fromFirestore)),
    );
  }

  Stream<List<Plant>> watchPlantsInGarden(String gardenId) {
    return _plants.snapshots().map(
      (snapshot) => [
        for (final plant in activePlantsIn(
          snapshot.docs.map(Plant.fromFirestore),
        ))
          if (plant.gardenId == gardenId) plant,
      ],
    );
  }

  Stream<Plant?> watchPlant(String plantId) {
    return _plants
        .doc(plantId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists ? Plant.fromFirestore(snapshot) : null,
        );
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
  /// reference the plant immediately. Chores are not created with the plant;
  /// the plant page adds them once a care profile exists.
  Future<String> createPlant(Plant plant) {
    return guardFirebase(() async {
      final id = plant.id.isEmpty ? _uuid.v4() : plant.id;
      await _plants.doc(id).set(plant.toCreateJson());
      return id;
    });
  }

  Future<void> updatePlant(Plant plant) {
    return guardFirebase(
      () => _plants
          .doc(plant.id)
          .set(plant.toUpdateJson(), SetOptions(merge: true)),
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

final plantRepositoryProvider = Provider<PlantRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (usesWorkerApi) {
    return WorkerPlantRepository(
      firestore: firestore,
      userId: userId,
      backend: ref.watch(workerBackendProvider),
    );
  }
  return PlantRepository(firestore: firestore, userId: userId);
});

final activePlantsProvider = StreamProvider<List<Plant>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(plantRepositoryProvider).watchActivePlants();
});

/// One plant, watched rather than fetched: `onPlantCreated` fills in the
/// species snapshot a moment after the document appears.
final plantProvider = StreamProvider.family<Plant?, String>((ref, plantId) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(null);
  }
  return ref.watch(plantRepositoryProvider).watchPlant(plantId);
});
