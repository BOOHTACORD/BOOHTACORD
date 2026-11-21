import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> control([String? mode]) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(
      mode == null ? 'GET' : 'POST',
      Uri.parse('https://localhost:4910/qa-r2/control'),
    );
    request.headers.set(
      'authorization',
      'Bearer ${const String.fromEnvironment('QA_R2_TOKEN')}',
    );
    if (mode != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'mode': mode}));
    }
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) throw StateError('Owned R2 control failed');
    return jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<void> revokeSession(String cookie) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('https://localhost:4910/api/v1/auth/logout'),
    );
    request.headers.set('cookie', cookie);
    request.headers.set('origin', 'https://localhost:4910');
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 204) {
      throw StateError('Owned server logout failed');
    }
    await response.drain<void>();
  } finally {
    client.close(force: true);
  }
}
