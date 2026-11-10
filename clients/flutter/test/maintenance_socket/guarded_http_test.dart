import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../integration_test/guarded_http.dart';

void main() {
  test(
    'blocks and counts legacy paths before they reach the real HTTP client',
    () async {
      var delivered = 0;
      final client = GuardedHttpClient(
        delegate: MockClient((_) async {
          delivered++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);
      for (final path in [
        '/api/v1/maintenance/events',
        '/api/v1/voice/rosters/events',
      ]) {
        await expectLater(
          client.get(Uri.parse('https://localhost:4810$path')),
          throwsStateError,
        );
      }
      expect(client.legacyRequests, 2);
      expect(delivered, 0);
      await client.get(Uri.parse('https://localhost:4810/api/v1/maintenance'));
      expect(delivered, 1);
    },
  );
}
