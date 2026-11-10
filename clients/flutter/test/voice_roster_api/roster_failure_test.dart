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

  test(
    'rejects a roster member without the required microphone state',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'channels': [
                  {
                    'channel_id': 'voice-1',
                    'participants': [
                      {
                        'account_id': 'account-2',
                        'display_name': 'Мика',
                        'screen_sharing': false,
                      },
                    ],
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(api.voiceParticipants(), throwsFormatException);
    },
  );

  test('reports unavailable private voice presence from the API', () async {
    final api = ApiClient(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {
                'code': 'VOICE_PRESENCE_UNAVAILABLE',
                'message': 'Не удалось загрузить участников голосовых комнат',
              },
            }),
          ),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      api.voiceParticipants(),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.status, 'status', 503)
            .having(
              (failure) => failure.code,
              'code',
              'VOICE_PRESENCE_UNAVAILABLE',
            ),
      ),
    );
  });
}
