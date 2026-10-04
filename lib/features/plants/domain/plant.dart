import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';

enum LocationType {
  indoor('indoor'),
  outdoor('outdoor'),
  greenhouse('greenhouse'),
  other('other');

  const LocationType(this.wire);
  final String wire;

  static LocationType fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => LocationType.other,
  );
}

enum GrowingMethod {
  container('container'),
  inGround('in_ground'),
  raisedBed('raised_bed'),
  hydroponic('hydroponic'),
  other('other');

  const GrowingMethod(this.wire);
  final String wire;

  static GrowingMethod fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => GrowingMethod.other,
  );
}

enum PlantAgeStage {
  seed('seed'),
  seedling('seedling'),
  youngEstablishing('young_establishing'),
  mature('mature'),
  unknown('unknown');

  const PlantAgeStage(this.wire);
  final String wire;

  static PlantAgeStage fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => PlantAgeStage.unknown,
  );
}

enum SunExposure {
  fullSun('full_sun'),
  partialSun('partial_sun'),
  partialShade('partial_shade'),
  fullShade('full_shade'),
  brightIndirect('bright_indirect'),
  lowLight('low_light'),
  unknown('unknown');

  const SunExposure(this.wire);
  final String wire;

  static SunExposure fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => SunExposure.unknown,
  );
}

enum PlantHealth {
  healthy('healthy'),
  needsAttention('needs_attention'),
  recovering('recovering'),
  unknown('unknown');

  const PlantHealth(this.wire);
  final String wire;

  static PlantHealth fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => PlantHealth.unknown,
  );
}

/// How well the plant's species resolved against the shared catalog.
///
/// Written by `onPlantCreated`, never by the client. `speciesMissing` means
/// the species has not been cached yet and `resolveSpecies` should be called.
enum CatalogStatus {
  resolved('resolved'),
  speciesMissing('species_missing'),
  unknown('unknown');

  const CatalogStatus(this.wire);
  final String wire;

  static CatalogStatus fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => CatalogStatus.unknown,
  );
}

class PlantContainer {
  const PlantContainer({
    this.isContainer = false,
    this.material,
    this.diameterCm,
    this.volumeLiters,
    this.hasDrainageHole = true,
  });

  final bool isContainer;
  final String? material;
  final double? diameterCm;
  final double? volumeLiters;
  final bool hasDrainageHole;

  factory PlantContainer.fromMap(Map<String, dynamic> map) => PlantContainer(
    isContainer: FirestoreValue.boolean(map['isContainer']),
    material: FirestoreValue.text(map['material']),
    diameterCm: FirestoreValue.decimal(map['diameterCm']),
    volumeLiters: FirestoreValue.decimal(map['volumeLiters']),
    hasDrainageHole: FirestoreValue.boolean(
      map['hasDrainageHole'],
      fallback: true,
    ),
  );

  Map<String, Object?> toMap() => {
    'isContainer': isContainer,
    'material': material,
    'diameterCm': diameterCm,
    'volumeLiters': volumeLiters,
    'hasDrainageHole': hasDrainageHole,
  };
}

class PlantEnvironment {
  const PlantEnvironment({
    this.sunExposure = SunExposure.unknown,
    this.sunHoursEstimate,
    this.soilType,
    this.mulched,
  });

  final SunExposure sunExposure;
  final double? sunHoursEstimate;
  final String? soilType;
  final bool? mulched;

  factory PlantEnvironment.fromMap(Map<String, dynamic> map) =>
      PlantEnvironment(
        sunExposure: SunExposure.fromWire(map['sunExposure']),
        sunHoursEstimate: FirestoreValue.decimal(map['sunHoursEstimate']),
        soilType: FirestoreValue.text(map['soilType']),
        mulched: map['mulched'] is bool ? map['mulched'] as bool : null,
      );

  Map<String, Object?> toMap() => {
    'sunExposure': sunExposure.wire,
    'sunHoursEstimate': sunHoursEstimate,
    'soilType': soilType,
    'mulched': mulched,
  };
}

class PlantStatus {
  const PlantStatus({
    this.health = PlantHealth.unknown,
    this.isArchived = false,
    this.isAlive = true,
    this.lastHealthCheckAt,
  });

  final PlantHealth health;
  final bool isArchived;
  final bool isAlive;

  /// Advanced by the `health_check` care event, through Cloud Functions.
  final DateTime? lastHealthCheckAt;

  factory PlantStatus.fromMap(Map<String, dynamic> map) => PlantStatus(
    health: PlantHealth.fromWire(map['health']),
    isArchived: FirestoreValue.boolean(map['isArchived']),
    isAlive: FirestoreValue.boolean(map['isAlive'], fallback: true),
    lastHealthCheckAt: FirestoreValue.dateTime(map['lastHealthCheckAt']),
  );

  Map<String, Object?> toMap() => {
    'health': health.wire,
    'isArchived': isArchived,
    'isAlive': isAlive,
  };
}

/// Last-done timestamps, maintained by `onCareEventCreated`.
///
/// Read-only in practice: log a care event and let the trigger advance these,
/// so the plant and its history can never disagree.
class PlantCurrentCare {
  const PlantCurrentCare({
    this.lastWateredAt,
    this.lastFertilizedAt,
    this.lastPrunedAt,
    this.lastRepottedAt,
    this.lastPestInspectionAt,
  });

  final DateTime? lastWateredAt;
  final DateTime? lastFertilizedAt;
  final DateTime? lastPrunedAt;
  final DateTime? lastRepottedAt;
  final DateTime? lastPestInspectionAt;

  factory PlantCurrentCare.fromMap(Map<String, dynamic> map) =>
      PlantCurrentCare(
        lastWateredAt: FirestoreValue.dateTime(map['lastWateredAt']),
        lastFertilizedAt: FirestoreValue.dateTime(map['lastFertilizedAt']),
        lastPrunedAt: FirestoreValue.dateTime(map['lastPrunedAt']),
        lastRepottedAt: FirestoreValue.dateTime(map['lastRepottedAt']),
        lastPestInspectionAt: FirestoreValue.dateTime(
          map['lastPestInspectionAt'],
        ),
      );
}

/// Next-due timestamps, also maintained by Cloud Functions.
class PlantNextActions {
  const PlantNextActions({
    this.nextWaterCheckAt,
    this.nextFertilizeAt,
    this.nextPestCheckAt,
  });

  final DateTime? nextWaterCheckAt;
  final DateTime? nextFertilizeAt;
  final DateTime? nextPestCheckAt;

  factory PlantNextActions.fromMap(Map<String, dynamic> map) =>
      PlantNextActions(
        nextWaterCheckAt: FirestoreValue.dateTime(map['nextWaterCheckAt']),
        nextFertilizeAt: FirestoreValue.dateTime(map['nextFertilizeAt']),
        nextPestCheckAt: FirestoreValue.dateTime(map['nextPestCheckAt']),
      );
}

/// One plant owned by one user, at /users/{uid}/plants/{plantId}.
class Plant {
  const Plant({
    required this.id,
    required this.speciesId,
    required this.displayName,
    this.cultivarId,
    this.gardenId,
    this.locationType = LocationType.indoor,
    this.growingMethod = GrowingMethod.container,
    this.speciesNameSnapshot,
    this.plantGroupSnapshot = const [],
    this.careProfileId,
    this.acquiredAt,
    this.plantedAt,
    this.plantAgeStage = PlantAgeStage.unknown,
    this.container = const PlantContainer(),
    this.environment = const PlantEnvironment(),
    this.status = const PlantStatus(),
    this.currentCare = const PlantCurrentCare(),
    this.nextActions = const PlantNextActions(),
    this.coverPhotoPath,
    this.catalogStatus = CatalogStatus.unknown,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String speciesId;
  final String displayName;
  final String? cultivarId;
  final String? gardenId;
  final LocationType locationType;
  final GrowingMethod growingMethod;

  /// Denormalized from the species so a garden list needs no extra reads.
  final String? speciesNameSnapshot;
  final List<String> plantGroupSnapshot;

  final String? careProfileId;
  final DateTime? acquiredAt;
  final DateTime? plantedAt;
  final PlantAgeStage plantAgeStage;
  final PlantContainer container;
  final PlantEnvironment environment;
  final PlantStatus status;
  final PlantCurrentCare currentCare;
  final PlantNextActions nextActions;

  /// Storage path, not a download URL, so links can be re-signed on demand.
  final String? coverPhotoPath;
  final CatalogStatus catalogStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Plant.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.requireData();
    return Plant(
      id: snapshot.id,
      speciesId: FirestoreValue.requireText(data['speciesId'], 'speciesId'),
      displayName: FirestoreValue.requireText(
        data['displayName'],
        'displayName',
      ),
      cultivarId: FirestoreValue.text(data['cultivarId']),
      gardenId: FirestoreValue.text(data['gardenId']),
      locationType: LocationType.fromWire(data['locationType']),
      growingMethod: GrowingMethod.fromWire(data['growingMethod']),
      speciesNameSnapshot: FirestoreValue.text(data['speciesNameSnapshot']),
      plantGroupSnapshot: FirestoreValue.strings(data['plantGroupSnapshot']),
      careProfileId: FirestoreValue.text(data['careProfileId']),
      acquiredAt: FirestoreValue.dateTime(data['acquiredAt']),
      plantedAt: FirestoreValue.dateTime(data['plantedAt']),
      plantAgeStage: PlantAgeStage.fromWire(data['plantAgeStage']),
      container: PlantContainer.fromMap(FirestoreValue.map(data['container'])),
      environment: PlantEnvironment.fromMap(
        FirestoreValue.map(data['environment']),
      ),
      status: PlantStatus.fromMap(FirestoreValue.map(data['status'])),
      currentCare: PlantCurrentCare.fromMap(
        FirestoreValue.map(data['currentCare']),
      ),
      nextActions: PlantNextActions.fromMap(
        FirestoreValue.map(data['nextActions']),
      ),
      coverPhotoPath: FirestoreValue.text(data['coverPhotoPath']),
      catalogStatus: CatalogStatus.fromWire(data['catalogStatus']),
      createdAt: FirestoreValue.dateTime(data['createdAt']),
      updatedAt: FirestoreValue.dateTime(data['updatedAt']),
    );
  }

  /// Every key the Firestore rules require on create is written here.
  ///
  /// `currentCare`, `nextActions` and `catalogStatus` are owned by Cloud
  /// Functions and deliberately left out.
  Map<String, Object?> toCreateJson() => {
    'speciesId': speciesId,
    'displayName': displayName,
    'cultivarId': cultivarId,
    'gardenId': gardenId,
    'locationType': locationType.wire,
    'growingMethod': growingMethod.wire,
    'plantAgeStage': plantAgeStage.wire,
    'careProfileId': careProfileId,
    'acquiredAt': acquiredAt,
    'plantedAt': plantedAt,
    'container': container.toMap(),
    'environment': environment.toMap(),
    'status': status.toMap(),
    'coverPhotoPath': coverPhotoPath,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };

  /// The rules re-validate the whole shape on update, so the required keys are
  /// always resent.
  Map<String, Object?> toUpdateJson() => {
    'speciesId': speciesId,
    'displayName': displayName,
    'locationType': locationType.wire,
    'growingMethod': growingMethod.wire,
    'plantAgeStage': plantAgeStage.wire,
    ...withoutNulls({
      'cultivarId': cultivarId,
      'gardenId': gardenId,
      'careProfileId': careProfileId,
      'acquiredAt': acquiredAt,
      'plantedAt': plantedAt,
      'coverPhotoPath': coverPhotoPath,
    }),
    'container': container.toMap(),
    'environment': environment.toMap(),
    'status': status.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };
}
