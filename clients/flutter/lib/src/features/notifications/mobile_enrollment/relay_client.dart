import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:uuid/uuid.dart';

import '../mobile_driver/config.dart';
import '../mobile_driver/contracts.dart';
import '../relay_auth/signature.dart';

class RelayClient {
  RelayClient(this.config, {http.Client? client})
    : client = client ?? IOClient(HttpClient()..findProxy = (_) => 'DIRECT');
  final PushBuildConfig config;
  final http.Client client;
  Future<Map<String, dynamic>> call(
    String method,
    String path,
    Map<String, dynamic> body, {
    List<int>? seed,
    String? device,
  }) async {
    if (!config.configured ||
        !RegExp(r'^/v1/[a-z0-9_/-]+$').hasMatch(path) ||
        path.contains('//')) {
      throw const PushUnavailable('configuration');
    }
    final bytes = utf8.encode(jsonEncode(body));
    final request = http.Request(method, Uri.parse(config.relayOrigin + path))
      ..followRedirects = false
      ..bodyBytes = bytes;
    request.headers['Content-Type'] = 'application/json';
    if (seed != null && device != null) {
      request.headers.addAll(
        await signRelayHeaders(
          seed: seed,
          role: 'device',
          subject: device,
          method: method,
          path: path,
          body: bytes,
          now: DateTime.now().toUtc(),
          nonce: const Uuid().v4(),
        ),
      );
    }
    return _response(request).timeout(const Duration(seconds: 8));
  }

  Future<Map<String, dynamic>> _response(http.Request request) async {
    final response = await client.send(request);
    final chunks = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 8),
    )) {
      if (chunks.length + chunk.length > 16384) {
        throw const PushUnavailable('relay_unavailable');
      }
      chunks.addAll(chunk);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PushUnavailable('relay_unavailable');
    }
    if (response.statusCode == 204) return {};
    final result = jsonDecode(utf8.decode(chunks));
    if (result is! Map<String, dynamic>) {
      throw const PushUnavailable('relay_unavailable');
    }
    return result;
  }

  void close() => client.close();
}
