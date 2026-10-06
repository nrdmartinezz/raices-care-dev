import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/errors/app_exception.dart';

/// How a picked photo is framed and how large the upload may be.
enum PhotoCrop {
  /// Profile and onboarding. The avatar is a circle, so the crop is square.
  square(maxEdge: 512),

  /// A plant cover. The garden card is wide, so the crop is 4:3.
  landscape(maxEdge: 1280);

  const PhotoCrop({required this.maxEdge});

  /// Longest edge of the JPEG that gets uploaded.
  final int maxEdge;

  /// Width / height of the crop frame.
  double get aspectRatio => switch (this) {
    PhotoCrop.square => 1,
    PhotoCrop.landscape => 4 / 3,
  };

  bool get circularMask => this == PhotoCrop.square;
}

/// JPEG quality used for every upload. High enough to stay sharp at card size.
const gardenJpegQuality = 80;

/// Shrinks [bytes] to [crop]'s pixel cap and returns a JPEG.
///
/// The crop screen has already chosen the frame. This only controls the file
/// that is uploaded, so a phone original cannot reach Storage at full size.
Uint8List encodeGardenJpeg(Uint8List bytes, {required PhotoCrop crop}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    throw const MalformedDataException('That photo could not be opened.');
  }
  if (decoded == null) {
    throw const MalformedDataException('That photo could not be opened.');
  }

  final resized = switch (crop) {
    PhotoCrop.square => img.copyResize(
      decoded,
      width: crop.maxEdge,
      height: crop.maxEdge,
      interpolation: img.Interpolation.linear,
    ),
    PhotoCrop.landscape => _fitLongestEdge(decoded, crop.maxEdge),
  };
  return img.encodeJpg(resized, quality: gardenJpegQuality);
}

img.Image _fitLongestEdge(img.Image source, int edge) {
  if (source.width >= source.height) {
    if (source.width <= edge) {
      return source;
    }
    return img.copyResize(
      source,
      width: edge,
      interpolation: img.Interpolation.linear,
    );
  }
  if (source.height <= edge) {
    return source;
  }
  return img.copyResize(
    source,
    height: edge,
    interpolation: img.Interpolation.linear,
  );
}
