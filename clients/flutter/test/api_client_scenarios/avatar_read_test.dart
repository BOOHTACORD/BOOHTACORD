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

  test('loads a private avatar with the current session cookie', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response.bytes(const [137, 80, 78, 71], 200);
      }),
    );

    final bytes = await api.avatarBytes(
      '/api/v1/members/00000000-0000-4000-8000-000000000001/avatar',
    );

    expect(bytes, const [137, 80, 78, 71]);
    expect(request.url.host, 'v.bootybay.ru');
    expect(request.headers['cookie'], 'session=test-session');
    expect(request.headers['accept'], 'image/png');
  });

  test(
    'loads a member profile through the authenticated profile endpoint',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes(
            utf8.encode(
              '{"user_id":"member/one","login":"member","display_name":"Участник","role":"MEMBER","presence":"online"}',
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final member = await api.memberProfile('member/one');

      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/members/member%2Fone');
      expect(request.headers['cookie'], 'session=test-session');
      expect(member.displayName, 'Участник');
      expect(member.presence.name, 'online');
    },
  );

  test('rejects a cross-origin avatar before sending credentials', () async {
    var requested = false;
    final api = ApiClient(
      client: MockClient((_) async {
        requested = true;
        return http.Response('', 200);
      }),
    );

    await expectLater(
      api.avatarBytes(
        'https://example.test/api/v1/members/00000000-0000-4000-8000-000000000001/avatar',
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(requested, isFalse);
  });
}
