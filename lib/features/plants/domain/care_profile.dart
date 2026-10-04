import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';
import '../../care/domain/care_task_type.dart';

/// Records which upstream fields a derived profile was computed from, so it can
/// be re-derived when the derivation rules change.
class CareProfileDerivation {
  const CareProfileDerivation({
    required this.provider,
    required this.sourceId,
    this.fields = const [],
  });

  final String provider;
  final String sourceId;
  final List<String> fields;

  factory CareProfileDerivation.fromMap(Map<String, dynamic> map) =>
      CareProfileDerivation(
        provider: FirestoreValue.text(map['provider']) ?? 'unknown',
        sourceId: FirestoreValue.text(map['sourceId']) ?? 'unknown',
        fields: FirestoreValue.strings(map['fields']),
      );
}

/// One repeating task on a care profile. `onPlantCreated` turns each of these
/// into a reminder when a plant is added.
class CareProfileTask {
  const CareProfileTask({
    required this.taskType,
    required this.title,
    required this.intervalDays,
    this.instructions,
    this.priority = ReminderPriority.normal,
    this.basis = const [],
  });

  final ReminderTaskType taskType;
  final String title;
  final int intervalDays;
  final String? instructions;
  final ReminderPriority priority;

  /// Catalog fields the cadence came from. Empty means a default was used
  /// because the upstream record had nothing useful.
  final List<String> basis;

  /// True when no catalog data backed this cadence.
  bool get isDefaultCadence => basis.isEmpty;

  factory CareProfileTask.fromMap(Map<String, dynamic> map) => CareProfileTask(
    taskType: ReminderTaskType.fromWire(map['taskType']),
    title: FirestoreValue.text(map['title']) ?? 'Care task',
    intervalDays: FirestoreValue.integer(map['intervalDays']) ?? 7,
    instructions: FirestoreValue.text(map['instructions']),
    priority: ReminderPriority.fromWire(map['priority']),
    basis: FirestoreValue.strings(map['basis']),
  );
}

/// A care schedule at /species/{speciesId}/careProfiles/{profileId}.
///
/// Read-only from the client. Profiles are either derived from catalog growth
/// data by the `resolveSpecies` function, or hand-authored by an editor — and
/// a hand-authored one is never overwritten by the derivation.
class CareProfile {
  const CareProfile({
    required this.id,
    required this.label,
    this.isDerived = false,
    this.derivedFrom,
    this.tasks = const [],
  });

  final String id;
  final String label;
  final bool isDerived;
  final CareProfileDerivation? derivedFrom;
  final List<CareProfileTask> tasks;

  factory CareProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final raw = data['tasks'];
    return CareProfile(
      id: snapshot.id,
      label: FirestoreValue.text(data['label']) ?? 'Care profile',
      isDerived: FirestoreValue.boolean(data['isDerived']),
      derivedFrom: data['derivedFrom'] == null
          ? null
          : CareProfileDerivation.fromMap(
              FirestoreValue.map(data['derivedFrom']),
            ),
      tasks: raw is Iterable
          ? raw
                .whereType<Map>()
                .map(
                  (entry) =>
                      CareProfileTask.fromMap(entry.cast<String, dynamic>()),
                )
                .toList(growable: false)
          : const [],
    );
  }
}
