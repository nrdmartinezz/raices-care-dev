import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/assets.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/photo_encode.dart';
import 'photo_crop_screen.dart';

export '../domain/photo_encode.dart' show PhotoCrop;

/// Bytes chosen from the camera or the library, ready to upload.
class PickedGardenPhoto {
  const PickedGardenPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Longest edge handed to the crop screen. The upload is smaller still.
const _pickerMaxEdge = 2048.0;

/// Asks for a source, crops, then returns a small JPEG.
///
/// Null when the gardener backs out of the source dialog or the crop.
Future<PickedGardenPhoto?> pickGardenPhoto(
  BuildContext context, {
  PhotoCrop crop = PhotoCrop.square,
}) async {
  final source = await showDialog<ImageSource>(
    context: context,
    barrierColor: appDialogBarrier,
    builder: (dialogContext) => AppDialog(
      icon: const AppIconBadge(icon: AppIcons.setupCamera),
      title: 'Add a photo',
      message: 'Take a new photo, or choose one from your library.',
      actions: Column(
        children: [
          AppDialogButton(
            label: 'Take a photo',
            filled: false,
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          AppDialogButton(
            label: 'Choose from library',
            filled: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) {
    return null;
  }

  try {
    // Start the picker, then cover the page immediately. The web picker
    // resizes the file after the dialog closes, and that wait used to sit
    // on the previous screen with nothing on it.
    final selection = _selectedPhoto(source);
    if (!context.mounted) {
      return null;
    }
    final cropped = await Navigator.of(context, rootNavigator: true)
        .push<Uint8List>(
          PageRouteBuilder<Uint8List>(
            fullscreenDialog: true,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (context, animation, secondaryAnimation) {
              return PhotoCropScreen(image: selection, crop: crop);
            },
          ),
        );
    if (cropped == null) {
      return null;
    }
    return PickedGardenPhoto(
      bytes: encodeGardenJpeg(cropped, crop: crop),
      contentType: 'image/jpeg',
    );
  } on AppException {
    rethrow;
  } on Object {
    throw const UnexpectedException('That photo could not be opened.');
  }
}

/// The chosen file, already limited to [_pickerMaxEdge], or null if cancelled.
Future<Uint8List?> _selectedPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: _pickerMaxEdge,
    maxHeight: _pickerMaxEdge,
  );
  if (file == null) {
    return null;
  }
  return file.readAsBytes();
}
