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

/// Longest edge of the picture shown in the crop screen.
///
/// The original stays off the UI thread. The crop frame only ever paints this
/// smaller JPEG, then the upload is smaller still.
const cropPreviewMaxEdge = 1600;

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

/// Shrinks [bytes] so the crop screen never decodes a camera original.
///
/// Meant to run off the UI isolate. A picture that is already small is
/// returned unchanged.
Uint8List downscaleGardenPreview(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    throw const MalformedDataException('That photo could not be opened.');
  }
  if (decoded == null) {
    throw const MalformedDataException('That photo could not be opened.');
  }
  if (decoded.width <= cropPreviewMaxEdge &&
      decoded.height <= cropPreviewMaxEdge) {
    return bytes;
  }
  return img.encodeJpg(
    _fitLongestEdge(decoded, cropPreviewMaxEdge),
    quality: gardenJpegQuality,
  );
}

/// Crops [bytes] to the given rectangle and returns the JPEG that gets uploaded.
///
/// Meant to run off the UI isolate. The rect is in the preview's pixels.
Uint8List cropAndEncodeGardenJpeg(
  Uint8List bytes, {
  required double left,
  required double top,
  required double width,
  required double height,
  required PhotoCrop crop,
}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    throw const MalformedDataException('That photo could not be opened.');
  }
  if (decoded == null) {
    throw const MalformedDataException('That photo could not be opened.');
  }

  final bounds = _clampCrop(
    imageWidth: decoded.width,
    imageHeight: decoded.height,
    left: left,
    top: top,
    width: width,
    height: height,
  );
  final cropped = img.copyCrop(
    decoded,
    x: bounds.x,
    y: bounds.y,
    width: bounds.width,
    height: bounds.height,
  );
  final resized = switch (crop) {
    PhotoCrop.square => img.copyResize(
      cropped,
      width: crop.maxEdge,
      height: crop.maxEdge,
      interpolation: img.Interpolation.linear,
    ),
    PhotoCrop.landscape => _fitLongestEdge(cropped, crop.maxEdge),
  };
  return img.encodeJpg(resized, quality: gardenJpegQuality);
}

/// Pixel size of the file produced for [crop] from a framed region.
({int width, int height}) gardenOutputSize({
  required int sourceWidth,
  required int sourceHeight,
  required PhotoCrop crop,
}) {
  return switch (crop) {
    PhotoCrop.square => (width: crop.maxEdge, height: crop.maxEdge),
    PhotoCrop.landscape => _fitSize(sourceWidth, sourceHeight, crop.maxEdge),
  };
}

({int x, int y, int width, int height}) _clampCrop({
  required int imageWidth,
  required int imageHeight,
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  if (imageWidth < 1 || imageHeight < 1) {
    throw const MalformedDataException('That photo could not be opened.');
  }
  final x = left.round().clamp(0, imageWidth - 1);
  final y = top.round().clamp(0, imageHeight - 1);
  final cropWidth = width.round().clamp(1, imageWidth - x);
  final cropHeight = height.round().clamp(1, imageHeight - y);
  return (x: x, y: y, width: cropWidth, height: cropHeight);
}

({int width, int height}) _fitSize(
  int sourceWidth,
  int sourceHeight,
  int edge,
) {
  if (sourceWidth >= sourceHeight) {
    if (sourceWidth <= edge) {
      return (width: sourceWidth, height: sourceHeight);
    }
    final height = (sourceHeight * edge / sourceWidth).round().clamp(1, edge);
    return (width: edge, height: height);
  }
  if (sourceHeight <= edge) {
    return (width: sourceWidth, height: sourceHeight);
  }
  final width = (sourceWidth * edge / sourceHeight).round().clamp(1, edge);
  return (width: width, height: edge);
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
