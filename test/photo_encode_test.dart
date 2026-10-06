import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:raices/core/errors/app_exception.dart';
import 'package:raices/features/photos/domain/photo_encode.dart';

void main() {
  test('a square crop becomes a 512 JPEG well under 10 MB', () {
    final jpeg = encodeGardenJpeg(
      _solidPng(width: 2400, height: 1800),
      crop: PhotoCrop.square,
    );
    final decoded = img.decodeImage(jpeg);

    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, 512);
    expect(_isJpeg(jpeg), isTrue);
    expect(jpeg.length, lessThan(1024 * 1024));
  });

  test('a landscape crop keeps the longest edge at 1280', () {
    final jpeg = encodeGardenJpeg(
      _solidPng(width: 3000, height: 2000),
      crop: PhotoCrop.landscape,
    );
    final decoded = img.decodeImage(jpeg);

    expect(decoded, isNotNull);
    expect(decoded!.width, 1280);
    expect(decoded.height, lessThanOrEqualTo(1280));
    expect(_isJpeg(jpeg), isTrue);
    expect(jpeg.length, lessThan(1024 * 1024));
  });

  test('a framed region becomes the upload JPEG off the preview pixels', () {
    final jpeg = cropAndEncodeGardenJpeg(
      _solidPng(width: 1600, height: 1200),
      left: 200,
      top: 100,
      width: 800,
      height: 800,
      crop: PhotoCrop.square,
    );
    final decoded = img.decodeImage(jpeg);

    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, 512);
    expect(_isJpeg(jpeg), isTrue);
  });

  test('a photo that cannot be read is rejected', () {
    expect(
      () => encodeGardenJpeg(
        Uint8List.fromList([1, 2, 3]),
        crop: PhotoCrop.square,
      ),
      throwsA(isA<MalformedDataException>()),
    );
  });
}

Uint8List _solidPng({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 110, 70));
  return img.encodePng(image);
}

bool _isJpeg(Uint8List bytes) =>
    bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
