import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/assets.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_dialog.dart';

/// Bytes chosen from the camera or the library, ready to upload.
class PickedGardenPhoto {
  const PickedGardenPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Asks for a source, then returns the image. Null when the gardener backs out.
Future<PickedGardenPhoto?> pickGardenPhoto(BuildContext context) async {
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
  if (source == null) {
    return null;
  }

  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return PickedGardenPhoto(
      bytes: bytes,
      contentType: _contentType(file.mimeType, file.name),
    );
  } on Object {
    throw const UnexpectedException('That photo could not be opened.');
  }
}

String _contentType(String? mime, String name) {
  final normalized = switch (mime?.toLowerCase()) {
    'image/jpg' || 'image/jpeg' => 'image/jpeg',
    'image/png' => 'image/png',
    'image/webp' => 'image/webp',
    'image/heic' || 'image/heif' => 'image/heic',
    _ => null,
  };
  if (normalized != null) {
    return normalized;
  }

  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}
