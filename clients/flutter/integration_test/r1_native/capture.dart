import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'harness.dart';

extension R1Capture on R1Harness {
  Future<void> capture(String name) async {
    await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    (report['screenshots']! as Map<String, String>)[name] = base64Encode(
      bytes!.buffer.asUint8List(),
    );
    image.dispose();
  }
}
