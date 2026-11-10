import 'dart:convert';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=test-session',
    });
  });

  test('completes password reset without placing token in URL', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    final token = List.filled(43, 'a').join();
    await api.completePasswordReset(token, 'a long password 123');

    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/auth/password-reset/complete');
    expect(request.url.query, isEmpty);
    expect(request.headers['content-type'], 'application/json');
    expect(request.body, contains('"token":"$token"'));
  });

  test('advances only the selected text channel read cursor', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response(
          '{"channel_id":"channel-1","message_id":"message-1","message_created_at":"2026-09-25T10:00:00Z"}',
          200,
        );
      }),
    );

    await api.advanceTextChannelReadCursor('channel-1', 'message-1');

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/channels/channel-1/read-cursor');
    expect(request.body, '{"message_id":"message-1"}');
  });

  test('parses unread and mention counts only for text channels', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            '{"revision":1,"categories":[{"id":"category-1","name":"Основное","channels":[{"id":"text-1","name":"общий","kind":"TEXT","position":0,"admission_closed":false,"unread_count":4,"mention_count":2},{"id":"voice-1","name":"голос","kind":"VOICE","position":1,"admission_closed":false}]}]}',
          ),
          200,
        ),
      ),
    );

    final channels = (await api.topology()).categories.single.channels;

    expect(channels[0].unreadCount, 4);
    expect(channels[0].mentionCount, 2);
    expect(channels[1].unreadCount, 0);
    expect(channels[1].mentionCount, 0);
  });
}
