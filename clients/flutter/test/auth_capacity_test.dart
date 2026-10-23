import 'dart:convert';

import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/features/session/authentication/api.dart';
import 'package:boohtacord_desktop/src/features/session/password_reset/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final operation in ['login', 'register', 'reset', 'change']) {
    test(
      '$operation capacity refusal preserves session and never retries automatically',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'boohtacord_session_cookie:https://v.bootybay.ru:443':
              'session=synthetic',
        });
        var calls = 0;
        var logout = 0;
        final transport = ApiTransport(
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'error': {'code': 'AUTH_BUSY', 'message': 'Сервер занят.'},
              }),
              503,
              headers: {'retry-after': '7', 'content-type': 'application/json'},
            );
          }),
        );
        transport.session.onUnauthorized = () => logout++;
        Future<void> action() async {
          switch (operation) {
            case 'login':
            case 'register':
              await AuthSessionApi(transport).authenticate(
                'synthetic-user',
                'synthetic password',
                register: operation == 'register',
              );
            case 'reset':
              await PasswordResetApi(
                transport,
              ).completePasswordReset('synthetic-token', 'synthetic password');
            default:
              await transport.checked(
                await transport.client.post(transport.uri('/me/password')),
              );
          }
        }

        await expectLater(
          action(),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.status, 'status', 503)
                .having((e) => e.code, 'code', 'AUTH_BUSY')
                .having(
                  (e) => e.message,
                  'manual retry',
                  contains('вручную через 7 с.'),
                ),
          ),
        );
        expect(calls, 1);
        expect(logout, 0);
        expect(await transport.session.readCookie(), 'session=synthetic');
        transport.client.close();
      },
    );
  }
}
