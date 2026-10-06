import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../domain/garden_image_url.dart';
import '../domain/plant_photo.dart';
import 'image_revision.dart';
import 'image_upload.dart';

/// Plant photos: bytes in R2, metadata in Firestore.
///
/// Takes raw bytes rather than a `File` so the same code path works on web.
class PhotoRepository {
  PhotoRepository({
    required this._firestore,
    required this._functions,
    required this._userId,
    this._onUploaded,
  });

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final String? _userId;
  final void Function(String storagePath)? _onUploaded;

  /// Checked before asking for an upload URL, so an oversized file fails
  /// immediately. The signer enforces the same ceiling.
  static const maxUploadBytes = 10 * 1024 * 1024;

  /// Uploads an image and records its metadata.
  ///
  /// The object key and the Firestore `storagePath` must agree: the rules
  /// require the recorded path to sit under this user's folder for this plant.
  Future<PlantPhoto> uploadPhoto({
    required String plantId,
    required Uint8List bytes,
    required String contentType,
    String? caption,
    DateTime? takenAt,
  }) async {
    _requireUserId();
    if (bytes.lengthInBytes > maxUploadBytes) {
      throw const MalformedDataException(
        'That image is larger than the 10 MB limit.',
      );
    }
    if (contentType != gardenJpegContentType) {
      throw const MalformedDataException('Only images can be uploaded.');
    }

    final signed = await uploadGardenJpeg(
      functions: _functions,
      kind: 'plant',
      plantId: plantId,
      bytes: bytes,
      onUploaded: _onUploaded,
    );
    final photoId = signed.photoId;
    if (photoId == null) {
      throw const UnexpectedException('That photo could not be saved.');
    }

    final photo = PlantPhoto(
      id: photoId,
      storagePath: signed.storagePath,
      caption: caption,
      takenAt: takenAt,
      sizeBytes: bytes.lengthInBytes,
      contentType: contentType,
    );

    await guardFirebase(
      () => _photos(plantId).doc(photoId).set(photo.toCreateJson()),
    );
    return photo;
  }

  Stream<List<PlantPhoto>> watchPhotos(String plantId) {
    return _photos(plantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PlantPhoto.fromFirestore).toList(),
        );
  }

  /// The custom-domain URL for a stored path.
  ///
  /// Only the path is persisted. A version query is added by the widgets that
  /// show a photo replaced during this session.
  String downloadUrl(String storagePath) => gardenImageUrl(storagePath);

  /// Removes the file and its metadata.
  ///
  /// The file goes first: a leftover metadata document is recoverable, whereas
  /// a leftover file with no record is invisible and keeps costing storage.
  Future<void> deletePhoto({
    required String plantId,
    required PlantPhoto photo,
  }) {
    return guardFirebase(() async {
      await _functions.httpsCallable('deleteImage').call<Map<String, dynamic>>({
        'storagePath': photo.storagePath,
      });
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
    functions: ref.watch(firebaseFunctionsProvider),
    userId: ref.watch(currentUserIdProvider),
    onUploaded: (path) => ref.read(imageRevisionProvider.notifier).bump(path),
  ),
);
