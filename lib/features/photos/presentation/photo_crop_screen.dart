import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_dialog.dart';
import '../domain/photo_encode.dart';
import '../domain/photo_work.dart';

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
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _left) {
        return;
      }
      final preview = await prepareCropPreview(bytes);
      if (!mounted || _left) {
        return;
      }
      setState(() => _bytes = preview);
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
    if (!_ready || _saving || _bytes == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // Crop runs against the frame under the circle after pan and pinch.
    // The rectangle from the first layout is the pre-zoom frame.
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    if (!mounted || _left) {
      return;
    }
    switch (result) {
      case CropFailure():
        setState(() {
          _saving = false;
          _error = 'That crop could not be saved.';
        });
      case CropSuccess(:final croppedImage):
        try {
          final jpeg = await encodeGardenUpload(
            croppedImage,
            crop: widget.crop,
          );
          _leave(jpeg);
        } on AppException catch (error) {
          if (!mounted || _left) {
            return;
          }
          setState(() {
            _saving = false;
            _error = error.message;
          });
        } on Object {
          if (!mounted || _left) {
            return;
          }
          setState(() {
            _saving = false;
            _error = 'That crop could not be saved.';
          });
        }
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
            Expanded(child: _editor()),
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

  Widget _editor() {
    final bytes = _bytes;
    if (bytes == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator(color: AppColors.terracotta)
            : const SizedBox.shrink(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The package sizes its circle from MediaQuery, which is the whole
        // phone. The title and buttons sit outside this pane, so the circle
        // has to be centered on the pane the gardener can see.
        final pane = Size(constraints.maxWidth, constraints.maxHeight);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: pane),
          child: Crop(
            image: bytes,
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
            onCropped: (result) => unawaited(_onCropped(result)),
          ),
        );
      },
    );
  }
}
