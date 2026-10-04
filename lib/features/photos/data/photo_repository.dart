import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/plant_photo.dart';

/// Plant photos: bytes in Storage, metadata in Firestore.
///
/// Takes raw bytes rather than a `File` so the same code path works on web.
class PhotoRepository {
  PhotoRepository({
    required this._firestore,
    required this._storage,
    required this._userId,
  });

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final String? _userId;

  static const _uuid = Uuid();

  /// Matches the ceiling in storage.rules. Checked here too, so an oversized
  /// file fails immediately instead of after a long upload.
  static const maxUploadBytes = 10 * 1024 * 1024;

  static const _allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
  };

  /// Uploads an image and records its metadata.
  ///
  /// The Storage path and the Firestore `storagePath` must agree: the rules
  /// require the recorded path to sit under this user's folder for this plant.
  Future<PlantPhoto> uploadPhoto({
    required String plantId,
    required Uint8List bytes,
    required String contentType,
    String? caption,
    DateTime? takenAt,
  }) {
    return guardFirebase(() async {
      final uid = _requireUserId();

      if (bytes.lengthInBytes > maxUploadBytes) {
        throw const MalformedDataException(
          'That image is larger than the 10 MB limit.',
        );
      }
      if (!_allowedContentTypes.contains(contentType)) {
        throw const MalformedDataException('Only images can be uploaded.');
      }

      final photoId = _uuid.v4();
      final extension = switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/heic' => 'heic',
        _ => 'jpg',
      };
      final storagePath = 'users/$uid/plants/$plantId/$photoId.$extension';

      await _storage.ref(storagePath).putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );

      final photo = PlantPhoto(
        id: photoId,
        storagePath: storagePath,
        caption: caption,
        takenAt: takenAt,
        sizeBytes: bytes.lengthInBytes,
        contentType: contentType,
      );

      await _photos(plantId).doc(photoId).set(photo.toCreateJson());
      return photo;
    });
  }

  Stream<List<PlantPhoto>> watchPhotos(String plantId) {
    return _photos(plantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PlantPhoto.fromFirestore).toList());
  }

  /// A temporary download URL for a stored path.
  ///
  /// These expire, which is why only the path is persisted.
  Future<String> downloadUrl(String storagePath) {
    return guardFirebase(() => _storage.ref(storagePath).getDownloadURL());
  }

  /// Removes the file and its metadata.
  ///
  /// The file goes first: a leftover metadata document is recoverable, whereas
  /// a leftover file with no record is invisible and keeps costing storage.
  Future<void> deletePhoto({
    required String plantId,
    required PlantPhoto photo,
  }) {
    return guardFirebase(() async {
      try {
        await _storage.ref(photo.storagePath).delete();
      } on FirebaseException catch (error) {
        // Already gone; carry on and clear the metadata.
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
      await _photos(plantId).doc(photo.id).delete();
    });
  }

  String _requireUserId() {
    final uid = _userId;
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _photos(String plantId) {
    return _firestore
        .collection('users')
        .doc(_requireUserId())
        .collection('plants')
        .doc(plantId)
        .collection('photos');
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(
    firestore: ref.watch(firestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);
