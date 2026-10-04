import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';

enum CareEventType {
  watered('watered'),
  fertilized('fertilized'),
  pruned('pruned'),
  repotted('repotted'),
  transplanted('transplanted'),
  harvested('harvested'),
  deadheaded('deadheaded'),
  mulched('mulched'),
  pestInspection('pest_inspection'),
  pestTreatment('pest_treatment'),
  diseaseObservation('disease_observation'),
  weatherDamage('weather_damage'),
  photoAdded('photo_added'),
  healthCheck('health_check'),
  planted('planted'),
  acquired('acquired'),
  archived('archived');

  const CareEventType(this.wire);
  final String wire;

  static CareEventType fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => CareEventType.healthCheck,
  );
}

enum PerformedBy {
  user('user'),
  system('system');

  const PerformedBy(this.wire);
  final String wire;

  static PerformedBy fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => PerformedBy.user,
  );
}

/// One entry in a plant's care history, at
/// /users/{uid}/plants/{plantId}/careEvents/{eventId}.
///
/// The history is append-oriented: the security rules deny updates outright,
/// so a logged event can be deleted but never rewritten. Logging an event is
/// also how a plant's `currentCare` and `nextActions` advance — the
/// `onCareEventCreated` trigger does that, rather than the client.
class CareEvent {
  const CareEvent({
    required this.id,
    required this.eventType,
    required this.occurredAt,
    this.performedBy = PerformedBy.user,
    this.details = const {},
    this.note,
    this.photoPaths = const [],
    this.createdAt,
  });

  final String id;
  final CareEventType eventType;
  final DateTime occurredAt;

  /// Clients may only write [PerformedBy.user]; the rules reject anything else.
  final PerformedBy performedBy;

  /// Event-specific payload, e.g. `{ "volumeMl": 150 }` for a watering.
  final Map<String, dynamic> details;
  final String? note;
  final List<String> photoPaths;
  final DateTime? createdAt;

  factory CareEvent.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.requireData();
    return CareEvent(
      id: snapshot.id,
      eventType: CareEventType.fromWire(data['eventType']),
      occurredAt: FirestoreValue.requireDateTime(
        data['occurredAt'],
        'occurredAt',
      ),
      performedBy: PerformedBy.fromWire(data['performedBy']),
      details: FirestoreValue.map(data['details']),
      note: FirestoreValue.text(data['note']),
      photoPaths: FirestoreValue.strings(data['photoPaths']),
      createdAt: FirestoreValue.dateTime(data['createdAt']),
    );
  }

  Map<String, Object?> toCreateJson() => {
    'eventType': eventType.wire,
    'occurredAt': Timestamp.fromDate(occurredAt),
    'performedBy': PerformedBy.user.wire,
    'details': details,
    'note': note,
    'photoPaths': photoPaths,
    'createdAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };
}
