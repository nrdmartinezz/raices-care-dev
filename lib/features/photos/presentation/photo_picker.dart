import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';

/// Bytes chosen from the camera or the library, ready to upload.
class PickedGardenPhoto {
  const PickedGardenPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Asks for a source, then returns the image. Null when the gardener backs out.
Future<PickedGardenPhoto?> pickGardenPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'ADD A PHOTO',
              style: AppText.eyebrow.copyWith(color: AppColors.terracotta),
            ),
          ),
          ListTile(
            title: Text(
              'Take a photo',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            title: Text(
              'Choose from library',
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
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
