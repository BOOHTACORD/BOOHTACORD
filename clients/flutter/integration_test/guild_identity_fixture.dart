import 'dart:convert';

import 'package:http/http.dart' as http;

// Independent real sessions never write the production client's secure storage.
class FixtureSession {
  FixtureSession(this.origin);
  final String origin;
  final http.Client client = http.Client();
  String? _cookie;
  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse('$origin$path'));
    request.headers.addAll({
      'origin': Uri.parse(origin).origin,
      'accept': 'application/json',
      'cookie': ?_cookie,
    });
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final result = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 20));
    final cookie = result.headers['set-cookie'];
    if (cookie != null) _cookie = cookie.split(';').first;
    return result;
  }

  Future<Map<String, dynamic>> json(
    String method,
    String path, {
    Object? body,
    int status = 200,
  }) async {
    final result = await request(method, path, body: body);
    if (result.statusCode != status) {
      throw StateError('Fixture HTTP status ${result.statusCode}');
    }
    return result.body.isEmpty
        ? {}
        : jsonDecode(result.body) as Map<String, dynamic>;
  }

  Future<void> login(String name, String password) async {
    await json(
      'POST',
      '/auth/login',
      status: 204,
      body: {'login': name, 'password': password},
    );
  }

  void close() => client.close();
}
