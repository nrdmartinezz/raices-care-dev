import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/photo_encode.dart';

/// Full-screen crop. Pops the cropped bytes, or null when cancelled.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes, required this.crop});

  final Uint8List bytes;
  final PhotoCrop crop;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _controller = CropController();
  var _ready = false;
  var _saving = false;
  String? _error;

  void _save() {
    if (!_ready || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) {
      return;
    }
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() {
          _saving = false;
          _error = 'That crop could not be saved.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Crop photo',
                style: AppText.display.copyWith(color: AppColors.ink),
              ),
            ),
            Expanded(
              child: Crop(
                image: widget.bytes,
                controller: _controller,
                aspectRatio: widget.crop.aspectRatio,
                withCircleUi: widget.crop.circularMask,
                interactive: true,
                fixCropRect: true,
                baseColor: AppColors.canvas,
                maskColor: AppColors.ink.withValues(alpha: 0.45),
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                  size: 0.85,
                  aspectRatio: widget.crop.aspectRatio,
                ),
                cornerDotBuilder: (size, edgeAlignment) =>
                    DotControl(color: AppColors.terracotta),
                progressIndicator: const Center(
                  child: CircularProgressIndicator(color: AppColors.terracotta),
                ),
                onStatusChanged: (status) {
                  if (!mounted) {
                    return;
                  }
                  setState(() => _ready = status == CropStatus.ready);
                },
                onCropped: _onCropped,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.terracotta),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: AppDialogButton(
                      label: 'Cancel',
                      filled: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDialogButton(
                      label: _saving ? 'Saving…' : 'Use photo',
                      filled: true,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
