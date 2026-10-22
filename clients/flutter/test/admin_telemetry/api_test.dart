import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'controller_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443': 'session=qa',
    }),
  );
  test('uses the existing private cookie/origin GET and PATCH contract, no secret fields', () async {
    final calls = <http.Request>[];
    final api = ApiClient(
      client: MockClient((r) async {
        calls.add(r);
        return http.Response(
          jsonEncode({...fixture(), 'credential': 'must-not-expose'}),
          200,
        );
      }),
    );
    final value = await api.readTelemetrySettings();
    expect(value.mode, 'local_only');
    await api.updateTelemetrySettings(
      'central',
      'https://center.example',
      true,
    );
    await api.updateTelemetrySettings('local_only', '', false);
    expect(calls.map((r) => r.method), ['GET', 'PATCH', 'PATCH']);
    for (final r in calls) {
      expect(r.url.path, '/api/v1/admin/telemetry');
      expect(r.headers['origin'], 'https://v.bootybay.ru');
      expect(r.headers['cookie'], 'session=qa');
    }
    expect(calls.first.headers['cache-control'], 'no-store');
    expect(jsonDecode(calls[1].body), {
      'mode': 'central',
      'endpoint': 'https://center.example',
      'confirmed': true,
    });
    expect(jsonDecode(calls[2].body), {'mode': 'local_only'});
  });
  test(
    'permission and old-server errors do not become successful settings',
    () async {
      for (final status in [403, 404, 429, 500]) {
        final api = ApiClient(
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await expectLater(
          api.readTelemetrySettings(),
          throwsA(isA<ApiFailure>()),
        );
      }
    },
  );
}
