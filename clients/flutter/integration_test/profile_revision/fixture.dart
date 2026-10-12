import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;

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
    Uint8List? bytes,
  }) async {
    final request = http.Request(method, Uri.parse('$origin$path'));
    request.headers.addAll({
      'origin': Uri.parse(origin).origin,
      'accept': 'application/json',
      'cookie': ?_cookie,
    });
    if (bytes != null) {
      request.headers['content-type'] = 'image/png';
      request.bodyBytes = bytes;
    } else if (body != null) {
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
      body: {'login': name, 'password': password},
      status: 204,
    );
  }

  Future<Map<String, dynamic>> rename(String alias) =>
      json('PATCH', '/me', body: {'display_name': alias});
  Future<void> upload(Uint8List bytes) async {
    final result = await request('PUT', '/me/avatar', bytes: bytes);
    if (result.statusCode != 200 && result.statusCode != 204) {
      throw StateError('Fixture avatar status ${result.statusCode}');
    }
  }

  void close() => client.close();
}

Uint8List solidAvatar(int r, int g, int b) {
  final canvas = image.Image(width: 64, height: 64);
  image.fill(canvas, color: image.ColorRgb8(r, g, b));
  return Uint8List.fromList(image.encodePng(canvas));
}
