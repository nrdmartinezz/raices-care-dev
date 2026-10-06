import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';

/// Loads a private Worker image with the Firebase ID token.
class AuthenticatedImage extends ImageProvider<AuthenticatedImage> {
  const AuthenticatedImage(this.client, this.path);

  final ApiClient client;
  final String path;

  @override
  Future<AuthenticatedImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    AuthenticatedImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
    );
  }

  Future<ui.Codec> _load(
    AuthenticatedImage key,
    ImageDecoderCallback decode,
  ) async {
    final bytes = await key.client.getBytes(key.path);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is AuthenticatedImage && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

const workerPhotoPrefix = 'worker-photo:';
const workerAvatarPath = 'worker-avatar';
