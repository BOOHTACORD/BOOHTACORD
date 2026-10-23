import 'dart:convert';

import 'package:boohtacord_desktop/src/core/http/api_failure.dart';
import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/session/password_reset/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ['unknown', 'expired', 'used', 'database failure']) {
    test('$kind reset uses safe feedback without retry or logout', () async {
      FlutterSecureStorage.setMockInitialValues({
        'boohtacord_session_cookie:https://v.bootybay.ru:443':
            'session=synthetic',
      });
      var calls = 0;
      var unauthorized = 0;
      final status = kind == 'database failure' ? 500 : 400;
      final transport = ApiTransport(
        client: MockClient((request) async {
          calls++;
          expect(request.url.toString(), isNot(contains('synthetic-token')));
          expect(jsonDecode(request.body), {
            'token': 'synthetic-token',
            'password': 'synthetic replacement password',
          });
          return http.Response(
            jsonEncode({
              'error': {
                'code': status == 400 ? 'VALIDATION_FAILED' : 'INTERNAL',
                'message': 'synthetic private infrastructure detail',
              },
            }),
            status,
          );
        }),
      );
      transport.session.onUnauthorized = () => unauthorized++;
      addTearDown(transport.client.close);
      await expectLater(
        PasswordResetApi(transport).completePasswordReset(
          'synthetic-token',
          'synthetic replacement password',
        ),
        throwsA(
          isA<ApiFailure>()
              .having((error) => error.status, 'status', status)
              .having(
                (error) => error.message,
                'safe feedback',
                contains(
                  status == 400
                      ? 'Ссылка недействительна'
                      : 'Не удалось изменить пароль',
                ),
              )
              .having(
                (error) => error.message,
                'no internal reflection',
                isNot(contains('private infrastructure')),
              ),
        ),
      );
      expect(calls, 1);
      expect(unauthorized, 0);
      expect(await transport.session.readCookie(), 'session=synthetic');
    });
  }
}
