import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'photo_encode.dart';

/// Shrinks a picked photo on a background isolate so the crop screen can paint.
Future<Uint8List> prepareCropPreview(Uint8List bytes) {
  return compute(downscaleGardenPreview, bytes);
}

/// Crops [source] out of the preview and encodes the upload JPEG off the UI.
Future<Uint8List> finishGardenCrop({
  required Uint8List bytes,
  required Rect source,
  required PhotoCrop crop,
}) {
  return compute(_finishJob, (
    bytes,
    source.left,
    source.top,
    source.width,
    source.height,
    crop.index,
  ));
}

Uint8List _finishJob((Uint8List, double, double, double, double, int) job) {
  return cropAndEncodeGardenJpeg(
    job.$1,
    left: job.$2,
    top: job.$3,
    width: job.$4,
    height: job.$5,
    crop: PhotoCrop.values[job.$6],
  );
}
