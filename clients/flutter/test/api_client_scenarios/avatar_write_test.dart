import 'dart:typed_data';

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

  test('uploads avatar bytes as the declared image type', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    await api.uploadOwnAvatar(Uint8List.fromList([1, 2, 3]), 'image/jpeg');

    expect(request.method, 'PUT');
    expect(request.url.path, '/api/v1/me/avatar');
    expect(request.headers['content-type'], 'image/jpeg');
    expect(request.headers['cookie'], 'session=test-session');
    expect(request.bodyBytes, [1, 2, 3]);
  });

  test('deletes only the authenticated account avatar', () async {
    late http.Request request;
    final api = ApiClient(
      client: MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );

    await api.deleteOwnAvatar();

    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/v1/me/avatar');
    expect(request.headers['cookie'], 'session=test-session');
  });

  test('keeps the session cookie when logout is not confirmed', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response('', 500);
        }
        return http.Response('{"authenticated":false}', 200);
      }),
    );

    await expectLater(api.logout(), throwsA(isA<ApiFailure>()));
    await api.currentSession();

    expect(requests.last.headers['cookie'], 'session=test-session');
  });
}
