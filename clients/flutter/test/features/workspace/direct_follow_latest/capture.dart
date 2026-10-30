import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String get captureDirectory =>
    Platform.environment['BOOHTACORD_QA609_CAPTURE_DIR'] ?? '';
Future<void> loadTailFonts() async {
  await (FontLoader(
    'Inter',
  )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
  if (captureDirectory.isEmpty) return;
  final root = Platform.environment['FLUTTER_ROOT'];
  expect(root, isNotNull);
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
      .load();
}

Future<void> captureTail(
  WidgetTester tester, {
  String name = 'incoming',
}) async {
  if (captureDirectory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('qa609-surface')),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  });
  Directory(captureDirectory).createSync(recursive: true);
  final target = File('$captureDirectory/$name.png');
  expect(target.existsSync(), isFalse);
  target.writeAsBytesSync(bytes!);
}
