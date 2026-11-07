import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class QaTls extends HttpOverrides {
  QaTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4810 &&
            sha256.convert(cert.der).toString() == pin;
}

class QaPeer {
  QaPeer(this.client, this.id, this.cookie, this.socket, this.origin);
  final http.Client client;
  final String id, cookie, origin;
  final WebSocket socket;
  static Future<QaPeer> start(String origin, String name) async {
    final client = http.Client();
    final headers = {
      'content-type': 'application/json',
      'origin': 'https://localhost:4810',
    };
    final body = jsonEncode({'login': name, 'password': 'synthetic123'});
    final created = await client.post(
      Uri.parse('$origin/auth/register'),
      headers: headers,
      body: body,
    );
    expect(created.statusCode, 201);
    final id =
        (jsonDecode(created.body) as Map<String, dynamic>)['id'] as String;
    final logged = await client.post(
      Uri.parse('$origin/auth/login'),
      headers: headers,
      body: body,
    );
    expect(logged.statusCode, 204);
    final cookie = logged.headers['set-cookie']!.split(';').first;
    final socket = await WebSocket.connect(
      'wss://localhost:4810/api/v1/realtime',
      headers: {'origin': 'https://localhost:4810', 'cookie': cookie},
    );
    return QaPeer(client, id, cookie, socket, origin);
  }

  Future<void> postMessage(String channelId) async {
    final r = await client.post(
      Uri.parse('$origin/channels/$channelId/messages'),
      headers: {
        'content-type': 'application/json',
        'origin': 'https://localhost:4810',
        'cookie': cookie,
      },
      body: jsonEncode({
        'client_message_id': '11111111-1111-4111-8111-111111111111',
        'body': 'Synthetic QA message',
      }),
    );
    expect(r.statusCode, 201);
  }

  Future<void> close() async {
    await socket.close();
    client.close();
  }
}
