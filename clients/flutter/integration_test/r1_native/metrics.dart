import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<int> authenticatedConnections() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:4920/metrics'),
    );
    final response = await request.close().timeout(const Duration(seconds: 5));
    expect(response.statusCode, 200);
    final text = StringBuffer();
    await for (final chunk
        in response
            .transform(utf8.decoder)
            .timeout(const Duration(seconds: 5))) {
      text.write(chunk);
      if (text.length > 2000000) {
        throw StateError('Owned metrics exceeded bound');
      }
    }
    final match = RegExp(
      r'^voice_platform_realtime_connections_active\{scope="authenticated"\} ([0-9.eE+\-]+)$',
      multiLine: true,
    ).firstMatch(text.toString());
    if (match == null) {
      throw StateError('Owned authenticated connection metric missing');
    }
    final value = double.parse(match[1]!);
    expect(
      value.isFinite && value >= 0 && value == value.roundToDouble(),
      isTrue,
    );
    return value.toInt();
  } finally {
    client.close(force: true);
  }
}
