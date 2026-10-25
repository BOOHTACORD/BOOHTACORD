import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/notifications/server_policy/policy.dart';

void main() {
  final root = File.fromUri(Platform.script).parent.parent.parent.parent.parent;
  final fixture = jsonDecode(
    File('${root.path}/contracts/notification-policy-v1.fixtures.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = fixture['cases'] as List<dynamic>;
  if (fixture['version'] != 1 || cases.length < 25) {
    throw StateError('Incomplete policy fixtures');
  }
  for (final value in cases) {
    final test = value as Map<String, dynamic>;
    final actual = evaluateNotificationPolicy(
      test['input'] as Map<String, dynamic>,
    );
    final expected = test['expected'] as Map<String, dynamic>;
    if (actual['eligible'] != expected['eligible'] ||
        actual['reason'] != expected['reason']) {
      throw StateError('${test['name']}: $actual expected $expected');
    }
  }
  stdout.writeln('PASS: ${cases.length} shared notification policy fixtures');
}
