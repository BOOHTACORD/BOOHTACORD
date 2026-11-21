import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

extension R1Restart on R1Harness {
  Future<void> restartApi() async {
    final uri = Uri.parse(const String.fromEnvironment('QA_CONTROL_URL'));
    expect(uri.scheme, 'http');
    expect(uri.host, '127.0.0.1');
    expect(uri.path, '/restart');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(
        'Authorization',
        'Bearer ${const String.fromEnvironment('QA_CONTROL_TOKEN')}',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      expect(response.statusCode, 204);
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
  }
}
