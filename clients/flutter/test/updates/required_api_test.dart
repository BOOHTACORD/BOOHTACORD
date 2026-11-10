import 'dart:convert';

import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('API rejects an invalid minimum before returning a policy', () async {
    Map<String, dynamic> payload(Object? minimum) => {
      'application_family': 'boohtacord',
      'catalog_revision': 1,
      'platform': 'android',
      'distribution': 'direct',
      'channel': 'stable',
      'arch': 'arm64',
      'state': 'published',
      'target': {
        'release_id': 'r5',
        'release_order': 5,
        'minimum_release_order': minimum,
        'version': '1',
        'native_build': '5',
        'priority': 'important',
        'summary': 'QA',
        'release_notes_url': '/notes',
        'requirements': {
          'supported_arches': ['arm64'],
        },
        'action': {'kind': 'open_instructions', 'url': '/download'},
      },
    };
    Object? minimum = 4;
    final api = UpdateApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(payload(minimum)),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
      baseUrl: () => 'https://example.test/api/v1',
    );
    final accepted = await api.fetch(const UpdateSelector.android('arm64'));
    expect(accepted.target?.minimumReleaseOrder, 4);
    minimum = 6;
    await expectLater(
      api.fetch(const UpdateSelector.android('arm64')),
      throwsFormatException,
    );
    minimum = 0;
    await expectLater(
      api.fetch(const UpdateSelector.android('arm64')),
      throwsFormatException,
    );
    minimum = '4';
    await expectLater(
      api.fetch(const UpdateSelector.android('arm64')),
      throwsA(isA<TypeError>()),
    );
  });
}
