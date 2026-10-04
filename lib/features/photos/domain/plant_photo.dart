import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';

/// Metadata for one uploaded photo, at
/// /users/{uid}/plants/{plantId}/photos/{photoId}.
///
/// Only metadata lives in Firestore; the image itself is in Storage at
/// [storagePath]. The security rules require that path to sit inside the
/// owner's own folder for this plant, which ties the two together.
class PlantPhoto {
  const PlantPhoto({
    required this.id,
    required this.storagePath,
    this.caption,
    this.takenAt,
    this.widthPx,
    this.heightPx,
    this.sizeBytes,
    this.contentType,
    this.createdAt,
  });

  final String id;

  /// Storage path, not a download URL. URLs expire; paths do not.
  final String storagePath;
  final String? caption;
  final DateTime? takenAt;
  final int? widthPx;
  final int? heightPx;
  final int? sizeBytes;
  final String? contentType;
  final DateTime? createdAt;

  factory PlantPhoto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.requireData();
    return PlantPhoto(
      id: snapshot.id,
      storagePath: FirestoreValue.requireText(
        data['storagePath'],
        'storagePath',
      ),
      caption: FirestoreValue.text(data['caption']),
      takenAt: FirestoreValue.dateTime(data['takenAt']),
      widthPx: FirestoreValue.integer(data['widthPx']),
      heightPx: FirestoreValue.integer(data['heightPx']),
      sizeBytes: FirestoreValue.integer(data['sizeBytes']),
      contentType: FirestoreValue.text(data['contentType']),
      createdAt: FirestoreValue.dateTime(data['createdAt']),
    );
  }

  Map<String, Object?> toCreateJson() => {
    'storagePath': storagePath,
    'caption': caption,
    'takenAt': takenAt == null ? null : Timestamp.fromDate(takenAt!),
    'widthPx': widthPx,
    'heightPx': heightPx,
    'sizeBytes': sizeBytes,
    'contentType': contentType,
    'createdAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };
}
