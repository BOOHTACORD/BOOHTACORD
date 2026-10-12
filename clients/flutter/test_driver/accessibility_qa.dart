import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Platform.environment['BOOHTACORD_NATIVE_CAPTURE_DIR'];
  if (output == null) throw StateError('QA output required');
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(name)) return false;
      await File('$output/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      final report = data?['accessibility_qa'];
      if (report != null) {
        await File('$output/scenario.json').writeAsString(jsonEncode(report));
      }
    },
    writeResponseOnFailure: true,
  );
}
