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

  test(
    'posts anonymous sender metrics with the authenticated origin',
    () async {
      late http.Request request;
      final api = ApiClient(
        client: MockClient((value) async {
          request = value;
          return http.Response('', 204);
        }),
      );

      await api.reportScreenShareMetrics({
        'platform': 'android_native',
        'direction': 'sender',
        'state': 'playing',
        'encoded_fps': 18,
        'bitrate_kbps': 960,
        'rtt_ms': 45,
      });

      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/voice/screen-metrics');
      expect(request.headers['origin'], 'https://v.bootybay.ru');
      expect(request.headers['cookie'], 'session=test-session');
      expect(request.headers['content-type'], 'application/json');
      expect(request.body, contains('"platform":"android_native"'));
      expect(request.body, isNot(contains('account')));
      expect(request.body, isNot(contains('channel')));
      expect(request.body, isNot(contains('track')));
    },
  );

  test(
    'reports unauthorized protected requests to the session owner',
    () async {
      var expired = false;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('', 401)),
      )..onUnauthorized = () => expired = true;

      await expectLater(api.members(), throwsA(isA<ApiFailure>()));

      expect(expired, isTrue);
    },
  );

  test(
    'does not treat invalid login credentials as an expired session',
    () async {
      var expired = false;
      final api = ApiClient(
        client: MockClient((_) async => http.Response('', 401)),
      )..onUnauthorized = () => expired = true;

      await expectLater(
        api.authenticate('member', 'bad-password-123', register: false),
        throwsA(isA<ApiFailure>()),
      );

      expect(expired, isFalse);
    },
  );
}
