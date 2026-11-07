import 'dart:convert';

import 'package:boohtacord_desktop/src/core/http/transport.dart';
import 'package:boohtacord_desktop/src/features/voice/sound_preferences/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const settings = {
  'enabled': true,
  'joined': true,
  'left': false,
  'started': true,
  'stopped': true,
  'allow_custom': false,
  'volume': 50,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('sends account fence and revision with session and origin', () async {
    final requests = <http.Request>[];
    final transport = ApiTransport(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'revision': requests.length - 1, 'settings': settings}),
          200,
        );
      }),
    );
    await transport.session.writeCookie('session=disposable');
    final api = VoiceSoundPreferencesApi(transport, 'account-a');
    final loaded = await api.load();
    final saved = await api.patch(loaded.revision, {'left': false});
    expect(saved.revision, 1);
    expect(requests.first.url.path, '/api/v1/me/voice-sound-preferences');
    expect(requests.last.method, 'PATCH');
    expect(requests.last.headers['x-voice-sound-account'], 'account-a');
    expect(requests.last.headers['cookie'], 'session=disposable');
    expect(requests.last.headers['origin'], 'https://v.bootybay.ru');
    expect(jsonDecode(requests.last.body), {
      'expected_revision': 0,
      'left': false,
    });
  });

  test('rejects invalid server settings and stale writes', () async {
    var calls = 0;
    final transport = ApiTransport(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'revision': 0,
              'settings': {...settings, 'volume': 101},
            }),
            200,
          );
        }
        return http.Response('{}', 409);
      }),
    );
    final api = VoiceSoundPreferencesApi(transport, 'account-a');
    await expectLater(api.load(), throwsFormatException);
    await expectLater(
      api.patch(0, {'left': false}),
      throwsA(isA<VoiceSoundPreferenceConflict>()),
    );
  });

  test('rejects an unacknowledged write and malformed local changes', () async {
    var calls = 0;
    final transport = ApiTransport(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({'revision': 1, 'settings': settings}),
          200,
        );
      }),
    );
    final api = VoiceSoundPreferencesApi(transport, 'account-a');
    await expectLater(api.patch(0, {'joined': false}), throwsFormatException);
    await expectLater(api.patch(0, {'volume': 101}), throwsFormatException);
    await expectLater(
      api.patch(0, {'unexpected': false}),
      throwsFormatException,
    );
    expect(calls, 1);
  });

  test(
    'refuses redirects without forwarding session or account fence',
    () async {
      var calls = 0;
      final transport = ApiTransport(
        client: MockClient((request) async {
          calls++;
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.invalid/'},
          );
        }),
      );
      await expectLater(
        VoiceSoundPreferencesApi(transport, 'account-a').load(),
        throwsException,
      );
      expect(calls, 1);
    },
  );
}
