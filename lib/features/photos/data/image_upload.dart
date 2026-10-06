import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../domain/garden_image_url.dart';

/// A short-lived PUT the signer prepared for one JPEG.
class SignedImageUpload {
  const SignedImageUpload({
    required this.storagePath,
    required this.uploadUrl,
    this.photoId,
  });

  final String storagePath;
  final String uploadUrl;
  final String? photoId;
}

/// Asks the signer for a PUT URL, then sends the JPEG.
///
/// The object key is chosen on the server. This only carries the bytes.
Future<SignedImageUpload> uploadGardenJpeg({
  required FirebaseFunctions functions,
  required String kind,
  required Uint8List bytes,
  String? plantId,
  void Function(String storagePath)? onUploaded,
}) {
  return guardFirebase(() async {
    if (bytes.isEmpty) {
      throw const MalformedDataException('That photo could not be saved.');
    }
    final payload = <String, Object?>{
      'kind': kind,
      'contentType': gardenJpegContentType,
      'contentLength': bytes.length,
      'plantId': ?plantId,
    };
    final response = await functions
        .httpsCallable('prepareImageUpload')
        .call<Map<String, dynamic>>(payload);
    final signed = _readSigned(response.data);
    final put = await http.put(
      Uri.parse(signed.uploadUrl),
      headers: const {
        'content-type': gardenJpegContentType,
        'cache-control': gardenImageCacheControl,
      },
      body: bytes,
    );
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw const UnexpectedException('That photo could not be saved.');
    }
    onUploaded?.call(signed.storagePath);
    return signed;
  });
}

SignedImageUpload _readSigned(Map<String, dynamic> data) {
  final storagePath = data['storagePath'];
  final uploadUrl = data['uploadUrl'];
  if (storagePath is! String ||
      storagePath.isEmpty ||
      uploadUrl is! String ||
      uploadUrl.isEmpty) {
    throw const UnexpectedException('That photo could not be saved.');
  }
  final photoId = data['photoId'];
  return SignedImageUpload(
    storagePath: storagePath,
    uploadUrl: uploadUrl,
    photoId: photoId is String && photoId.isNotEmpty ? photoId : null,
  );
}
