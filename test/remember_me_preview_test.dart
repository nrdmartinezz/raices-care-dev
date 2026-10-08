import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raices/app/theme.dart';
import 'package:raices/features/auth/presentation/widgets/remember_me_row.dart';

void main() {
  testWidgets('preview remember me checkmark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRaicesTheme(),
        home: const Scaffold(
          backgroundColor: Color(0xFFFFFFFF),
          body: Center(
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RememberMeRow(value: true, onChanged: _noop),
                  SizedBox(height: 12),
                  RememberMeRow(value: false, onChanged: _noop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 4),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File(
      'test/remember_me_preview.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void _noop(bool _) {}
