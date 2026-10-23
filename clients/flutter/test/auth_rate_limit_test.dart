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
  for (final operation in ['login', 'register']) {
    test(
      '$operation account admission refusal preserves session and never retries automatically',
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
                'error': {
                  'code': 'RATE_LIMITED',
                  'message': 'Слишком много попыток; повторите позже',
                },
              }),
              429,
              headers: {
                'retry-after': '30',
                'content-type': 'application/json',
              },
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
                .having((e) => e.status, 'status', 429)
                .having((e) => e.code, 'code', 'RATE_LIMITED')
                .having(
                  (e) => e.message,
                  'manual retry',
                  contains('вручную через 30 с.'),
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
  for (final header in [null, 'bad', '-1', '9999999999999999999999']) {
    test('malformed Retry-After uses manual fallback: $header', () async {
      FlutterSecureStorage.setMockInitialValues({});
      var calls = 0;
      final transport = ApiTransport(
        client: MockClient((_) async {
          calls++;
          return http.Response(
            '{"error":{"code":"RATE_LIMITED"}}',
            429,
            headers: {'retry-after': ?header},
          );
        }),
      );
      addTearDown(transport.client.close);
      await expectLater(
        AuthSessionApi(transport).authenticate(
          'synthetic-member',
          'synthetic password',
          register: false,
        ),
        throwsA(
          isA<ApiFailure>()
              .having(
                (error) => error.message,
                'safe manual guidance',
                contains('Подождите и повторите вручную.'),
              )
              .having((error) => error.retryAfter, 'unknown delay', isNull),
        ),
      );
      expect(calls, 1);
    });
  }
}
