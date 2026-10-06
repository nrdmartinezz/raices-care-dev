import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

import '../../../core/errors/app_exception.dart';
import 'photo_encode.dart';

/// Shrinks a picked photo with the browser decoder, off the UI thread.
Future<Uint8List> prepareCropPreview(Uint8List bytes) async {
  final bitmap = await _bitmap(bytes);
  final longest = math.max(bitmap.width, bitmap.height);
  if (longest <= cropPreviewMaxEdge) {
    final jpeg = await _encodeBitmap(bitmap);
    bitmap.close();
    return jpeg;
  }

  final scale = cropPreviewMaxEdge / longest;
  final resized = await web.window
      .createImageBitmap(
        bitmap,
        web.ImageBitmapOptions(
          resizeWidth: (bitmap.width * scale).round(),
          resizeHeight: (bitmap.height * scale).round(),
          resizeQuality: 'medium',
        ),
      )
      .toDart;
  bitmap.close();
  final jpeg = await _encodeBitmap(resized);
  resized.close();
  return jpeg;
}

/// Crops [source] in the browser and encodes the upload JPEG without blocking.
Future<Uint8List> finishGardenCrop({
  required Uint8List bytes,
  required Rect source,
  required PhotoCrop crop,
}) async {
  final bitmap = await _bitmap(bytes);
  final frame = _clamp(
    imageWidth: bitmap.width,
    imageHeight: bitmap.height,
    source: source,
  );
  final output = gardenOutputSize(
    sourceWidth: frame.width,
    sourceHeight: frame.height,
    crop: crop,
  );
  final canvas = web.HTMLCanvasElement()
    ..width = output.width
    ..height = output.height;
  canvas.context2D.drawImage(
    bitmap as web.CanvasImageSource,
    frame.x.toDouble(),
    frame.y.toDouble(),
    frame.width.toDouble(),
    frame.height.toDouble(),
    0,
    0,
    output.width.toDouble(),
    output.height.toDouble(),
  );
  bitmap.close();
  return _blobBytes(canvas);
}

Future<web.ImageBitmap> _bitmap(Uint8List bytes) {
  final blob = web.Blob([bytes.toJS].toJS);
  return web.window.createImageBitmap(blob).toDart;
}

Future<Uint8List> _encodeBitmap(web.ImageBitmap bitmap) {
  final canvas = web.HTMLCanvasElement()
    ..width = bitmap.width
    ..height = bitmap.height;
  canvas.context2D.drawImage(bitmap as web.CanvasImageSource, 0, 0);
  return _blobBytes(canvas);
}

/// JPEG encoding runs in the browser, so the page can keep painting.
Future<Uint8List> _blobBytes(web.HTMLCanvasElement canvas) {
  final completer = Completer<Uint8List>();
  canvas.toBlob(
    (JSAny? value) {
      final blob = value as web.Blob?;
      if (blob == null) {
        completer.completeError(
          const MalformedDataException('That photo could not be opened.'),
        );
        return;
      }
      blob.arrayBuffer().toDart.then((buffer) {
        if (!completer.isCompleted) {
          completer.complete(buffer.toDart.asUint8List());
        }
      }, onError: completer.completeError);
    }.toJS,
    'image/jpeg',
    (gardenJpegQuality / 100).toJS,
  );
  return completer.future;
}

({int x, int y, int width, int height}) _clamp({
  required int imageWidth,
  required int imageHeight,
  required Rect source,
}) {
  final x = source.left.round().clamp(0, imageWidth - 1);
  final y = source.top.round().clamp(0, imageHeight - 1);
  final width = source.width.round().clamp(1, imageWidth - x);
  final height = source.height.round().clamp(1, imageHeight - y);
  return (x: x, y: y, width: width, height: height);
}
