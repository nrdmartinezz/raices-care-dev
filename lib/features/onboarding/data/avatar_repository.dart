import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/authenticated_image.dart';
import '../../../core/api/worker_repositories.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../photos/data/image_revision.dart';
import '../../photos/data/image_upload.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/domain/garden_image_url.dart';

/// The optional profile photo at users/{uid}/profile/avatar.jpg.
class AvatarRepository {
  AvatarRepository({
    required this._functions,
    required this._userId,
    this._onUploaded,
  });

  final FirebaseFunctions _functions;
  final String? _userId;
  final void Function(String storagePath)? _onUploaded;

  /// Uploads [bytes] and returns the object key to store on the profile.
  ///
  /// The object name is fixed, so a new photo replaces the previous one.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (_userId == null) {
      throw const UnauthenticatedException();
    }
    if (bytes.lengthInBytes > PhotoRepository.maxUploadBytes) {
      throw const MalformedDataException(
        'That image is larger than the 10 MB limit.',
      );
    }
    if (contentType != gardenJpegContentType) {
      throw const MalformedDataException('Only images can be uploaded.');
    }

    final signed = await uploadGardenJpeg(
      functions: _functions,
      kind: 'avatar',
      bytes: bytes,
      onUploaded: _onUploaded,
    );
    return signed.storagePath;
  }
}

final avatarRepositoryProvider = Provider<AvatarRepository>((ref) {
  final functions = ref.watch(firebaseFunctionsProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (usesWorkerApi) {
    return WorkerAvatarRepository(
      functions: functions,
      userId: userId,
      backend: ref.watch(workerBackendProvider),
      onUploaded: (path) => ref.read(imageRevisionProvider.notifier).bump(path),
    );
  }
  return AvatarRepository(
    functions: functions,
    userId: userId,
    onUploaded: (path) => ref.read(imageRevisionProvider.notifier).bump(path),
  );
});

/// The custom-domain URL for a stored avatar path.
///
/// A version query is included after this session replaces the file, so the
/// circle does not keep the previous JPEG.
final avatarUrlProvider = Provider.family<String, String>((ref, path) {
  if (usesWorkerApi || path == workerAvatarPath) {
    return workerAvatarPath;
  }
  final version = ref.watch(imageRevisionProvider)[path];
  return gardenImageUrl(path, version: version);
});
