import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> capturePending(
  WidgetTester tester,
  Finder boundary,
  String name,
) async {
  final path = Platform.environment['BOOHTACORD_QA579_CAPTURE_DIR'];
  if (path == null) return;
  final directory = Directory(path);
  if (!directory.isAbsolute) {
    throw StateError('Absolute owned capture path required');
  }
  directory.createSync(recursive: true);
  final file = File('$path/$name.png');
  if (file.existsSync()) throw StateError('Preserve prior capture');
  await tester.pump();
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  final bytes = await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  file.writeAsBytesSync(bytes!);
}
