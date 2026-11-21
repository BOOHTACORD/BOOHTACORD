import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final output = Platform.environment['BOOHTACORD_NATIVE_CAPTURE_DIR'];
  if (output == null) throw StateError('Native R1 output directory required');
  await integrationDriver(
    responseDataCallback: (data) async {
      if (data == null || data['status'] != 'PASS') {
        throw StateError('Native R1 did not pass');
      }
      final captures = data['screenshots'] as Map<String, dynamic>;
      if (captures.length != 5) {
        throw StateError('Five native captures required');
      }
      for (final entry in captures.entries) {
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(entry.key)) {
          throw StateError('Invalid capture name');
        }
        final bytes = base64Decode(entry.value as String);
        if (bytes.length < 33 || bytes.length > 4000000 || bytes[0] != 137) {
          throw StateError('Invalid native PNG');
        }
        await File('$output/${entry.key}.png').writeAsBytes(bytes);
      }
      final report = Map<String, dynamic>.from(data)..remove('screenshots');
      await File('$output/scenario.json').writeAsString(jsonEncode(report));
    },
  );
}
