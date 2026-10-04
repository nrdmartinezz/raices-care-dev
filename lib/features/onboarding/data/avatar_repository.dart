import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../photos/data/photo_repository.dart';

/// The optional profile photo at users/{uid}/profile/avatar.jpg.
class AvatarRepository {
  AvatarRepository({required this._storage, required this._userId});

  final FirebaseStorage _storage;
  final String? _userId;

  static const _allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
  };

  /// Uploads [bytes] and returns the storage path to store on the profile.
  ///
  /// The object name is fixed, so a new photo replaces the previous one.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) {
    return guardFirebase(() async {
      final uid = _userId;
      if (uid == null) {
        throw const UnauthenticatedException();
      }
      if (bytes.lengthInBytes > PhotoRepository.maxUploadBytes) {
        throw const MalformedDataException(
          'That image is larger than the 10 MB limit.',
        );
      }
      if (!_allowedContentTypes.contains(contentType)) {
        throw const MalformedDataException('Only images can be uploaded.');
      }

      final path = 'users/$uid/profile/avatar.jpg';
      await _storage
          .ref(path)
          .putData(bytes, SettableMetadata(contentType: contentType));
      return path;
    });
  }
}

final avatarRepositoryProvider = Provider<AvatarRepository>(
  (ref) => AvatarRepository(
    storage: ref.watch(firebaseStorageProvider),
    userId: ref.watch(currentUserIdProvider),
  ),
);

/// A temporary download URL for a stored avatar path.
final avatarUrlProvider = FutureProvider.family<String, String>((ref, path) {
  return ref.watch(photoRepositoryProvider).downloadUrl(path);
});
