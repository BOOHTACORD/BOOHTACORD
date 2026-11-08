import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

Future<void> captureQaSoundWidgets(GlobalKey key, String name) async {
  const destination = String.fromEnvironment('QA_CAPTURE_DIR');
  if (destination.isEmpty) return;
  final context = key.currentContext!;
  final boundary = context.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(
    pixelRatio: View.of(context).devicePixelRatio,
  );
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(destination);
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}
