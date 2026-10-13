import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/features/screen/sender_metadata/descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtures = jsonDecode(
    File('../../contracts/screen-share-profile-v1.fixtures.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final row in fixtures['descriptorCases'] as List<dynamic>) {
    test('shared explicit scenario: ${row['name']}', () {
      final value = <String, Object?>{
        ...fixtures['validDescriptor'] as Map<String, dynamic>,
        ...row['overrides'] as Map<String, dynamic>,
      };
      final parsed = parseScreenShareDescriptor(
        jsonEncode(value),
        expectedOriginId: 'origin-a',
        expectedAccountId: 'account-a',
        expectedRoomId: 'room-a',
      );
      expect(parsed != null, row['accepted']);
      if (row['accepted'] == true) expect(parsed?.mode, value['mode']);
    });
  }
}
