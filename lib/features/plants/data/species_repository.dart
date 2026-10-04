import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/care_profile.dart';
import '../domain/species.dart';

/// One result from a catalog search, before the species has been cached.
class SpeciesCandidate {
  const SpeciesCandidate({
    required this.speciesId,
    required this.scientificName,
    this.commonName,
    this.family,
    this.imageUrl,
    this.trefleSlug,
    this.dataCompleteness,
  });

  final String speciesId;
  final String scientificName;
  final String? commonName;
  final String? family;
  final String? imageUrl;
  final String? trefleSlug;

  /// Upstream's 0–100 estimate of record completeness. Low values mean the
  /// derived care profile will mostly fall back to defaults.
  final int? dataCompleteness;

  String get displayName => commonName ?? scientificName;

  factory SpeciesCandidate.fromMap(Map<String, dynamic> map) =>
      SpeciesCandidate(
        speciesId: (map['speciesId'] as String?) ?? '',
        scientificName: (map['scientificName'] as String?) ?? '',
        commonName: map['commonName'] as String?,
        family: map['family'] as String?,
        imageUrl: map['imageUrl'] as String?,
        trefleSlug: map['trefleSlug'] as String?,
        dataCompleteness: (map['dataCompleteness'] as num?)?.toInt(),
      );
}

class SpeciesSearchResult {
  const SpeciesSearchResult({
    required this.candidates,
    required this.attribution,
  });

  final List<SpeciesCandidate> candidates;

  /// Licence credit that must be shown wherever these results appear.
  final String attribution;
}

/// Reads the shared species catalog.
///
/// The catalog is read-only to clients, and fills in lazily: searching and
/// caching both go through Cloud Functions, which hold the upstream API token.
/// Nothing here ever writes to /species directly.
class SpeciesRepository {
  SpeciesRepository({required this._firestore, required this._functions});

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<Species?> getSpecies(String speciesId) {
    return guardFirebase(() async {
      final snapshot = await _speciesRef(speciesId).get();
      return snapshot.exists ? Species.fromFirestore(snapshot) : null;
    });
  }

  Stream<Species?> watchSpecies(String speciesId) {
    return _speciesRef(speciesId).snapshots().map(
      (snapshot) => snapshot.exists ? Species.fromFirestore(snapshot) : null,
    );
  }

  Future<List<CareProfile>> getCareProfiles(String speciesId) {
    return guardFirebase(() async {
      final snapshot = await _speciesRef(
        speciesId,
      ).collection('careProfiles').get();
      return snapshot.docs.map(CareProfile.fromFirestore).toList();
    });
  }

  /// Provenance for a species, for rendering per-record attribution.
  Future<List<SpeciesSource>> getSources(String speciesId) {
    return guardFirebase(() async {
      final snapshot = await _speciesRef(speciesId).collection('sources').get();
      return snapshot.docs.map(SpeciesSource.fromFirestore).toList();
    });
  }

  /// Searches the upstream catalog. Writes nothing; results are candidates.
  Future<SpeciesSearchResult> search(String query) {
    return guardFirebase(() async {
      final response = await _functions
          .httpsCallable('searchSpeciesCatalog')
          .call<Map<String, dynamic>>({'query': query});

      final data = response.data;
      final raw = data['candidates'];

      return SpeciesSearchResult(
        attribution: (data['attribution'] as String?) ?? '',
        candidates: raw is Iterable
            ? raw
                  .whereType<Map>()
                  .map(
                    (entry) =>
                        SpeciesCandidate.fromMap(entry.cast<String, dynamic>()),
                  )
                  .toList()
            : const [],
      );
    });
  }

  /// Caches a species into /species and returns its id.
  ///
  /// Call this before creating a plant that references it, so `onPlantCreated`
  /// finds a care profile to seed reminders from.
  Future<String> resolve({String? speciesId, String? trefleSlug}) {
    return guardFirebase(() async {
      final response = await _functions
          .httpsCallable('resolveSpecies')
          .call<Map<String, dynamic>>({
            'speciesId': ?speciesId,
            'trefleSlug': ?trefleSlug,
          });

      final resolved = response.data['speciesId'] as String?;
      if (resolved == null || resolved.isEmpty) {
        throw const UnexpectedException('The catalog returned no species id.');
      }
      return resolved;
    });
  }

  DocumentReference<Map<String, dynamic>> _speciesRef(String speciesId) =>
      _firestore.collection('species').doc(speciesId);
}

final speciesRepositoryProvider = Provider<SpeciesRepository>(
  (ref) => SpeciesRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);
