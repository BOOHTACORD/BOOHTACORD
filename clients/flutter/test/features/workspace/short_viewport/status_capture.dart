import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> captureVoiceStatus(
  WidgetTester tester,
  Finder finder,
  String name,
) async {
  final directory = Platform.environment['BOOHTACORD_QA582_STATUS_CAPTURE_DIR'];
  if (directory == null) return;
  final path = File('$directory/$name.png');
  if (path.existsSync()) throw StateError('Preserve previous capture');
  Directory(directory).createSync(recursive: true);
  final render = tester.renderObject<RenderRepaintBoundary>(finder);
  final bytes = await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2.8125);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  path.writeAsBytesSync(bytes!);
}
