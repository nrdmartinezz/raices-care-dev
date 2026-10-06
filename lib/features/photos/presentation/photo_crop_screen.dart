import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/photo_encode.dart';

/// Full-screen crop. Pops the cropped bytes, or null when cancelled.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.image, required this.crop});

  /// The picked file. Null when the gardener cancels the source dialog.
  final Future<Uint8List?> image;
  final PhotoCrop crop;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _controller = CropController();
  Uint8List? _bytes;
  var _ready = false;
  var _saving = false;
  var _left = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_openImage());
  }

  Future<void> _openImage() async {
    try {
      final bytes = await widget.image;
      if (!mounted || _left) {
        return;
      }
      if (bytes == null) {
        _leave();
        return;
      }
      setState(() => _bytes = bytes);
    } on Object {
      if (!mounted || _left) {
        return;
      }
      setState(() => _error = 'That photo could not be opened.');
    }
  }

  void _leave([Uint8List? result]) {
    if (_left || !mounted) {
      return;
    }
    _left = true;
    Navigator.of(context).pop(result);
  }

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
        _leave(croppedImage);
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
              child: _bytes == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator(
                              color: AppColors.terracotta,
                            )
                          : const SizedBox.shrink(),
                    )
                  : Crop(
                      image: _bytes!,
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
                        child: CircularProgressIndicator(
                          color: AppColors.terracotta,
                        ),
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
                      onPressed: _leave,
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
