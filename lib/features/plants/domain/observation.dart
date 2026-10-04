import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';

/// A note the gardener wrote about one plant, at
/// /users/{uid}/plants/{plantId}/observations/{observationId}.
///
/// Care events record what was done; an observation records what was noticed.
/// The rules require a filled `note` of at most 5000 characters and nothing
/// else, so everything here apart from the note is optional.
class Observation {
  const Observation({
    required this.id,
    required this.note,
    required this.observedAt,
    this.photoPaths = const [],
    this.createdAt,
  });

  static const noteLimit = 5000;

  final String id;
  final String note;
  final DateTime observedAt;
  final List<String> photoPaths;
  final DateTime? createdAt;

  factory Observation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.requireData();
    return Observation(
      id: snapshot.id,
      note: FirestoreValue.requireText(data['note'], 'note'),
      // Older notes may predate the field; the write time is close enough.
      observedAt:
          FirestoreValue.dateTime(data['observedAt']) ??
          FirestoreValue.dateTime(data['createdAt']) ??
          DateTime.now(),
      photoPaths: FirestoreValue.strings(data['photoPaths']),
      createdAt: FirestoreValue.dateTime(data['createdAt']),
    );
  }

  Map<String, Object?> toCreateJson() => {
    'note': note,
    'observedAt': Timestamp.fromDate(observedAt),
    'photoPaths': photoPaths,
    'createdAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };
}
