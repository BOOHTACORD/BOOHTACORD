import 'dart:typed_data';
import 'dart:convert';

import 'package:boohtacord_desktop/src/features/voice/screen_preview/client.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_preview/uploader.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'boohtacord_session_cookie:https://v.bootybay.ru:443':
          'session=preview-test',
    });
  });

  test('accepts only bounded JPEG-shaped preview bytes', () {
    expect(
      validScreenPreviewJpeg(Uint8List.fromList([0xff, 0xd8, 1, 0xff, 0xd9])),
      isTrue,
    );
    expect(validScreenPreviewJpeg(Uint8List(14 * 1024 + 1)), isFalse);
    expect(
      validScreenPreviewJpeg(Uint8List.fromList([0xff, 0xd8, 1, 0])),
      isFalse,
    );
  });

  test('screen preview cap matches the backend contract', () {
    expect(maxScreenPreviewBytes, 14 * 1024);
  });

  test('starts and invalidates server-owned captures through private session routes', () async {
    final requests = <http.Request>[];
    const lease = 'd9428888-122b-4a50-8c5c-5b9393a4e5f1';
    const generation = 'e35d15a4-6d8c-4a6e-a6b9-78de899631f8';
    final api = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'schema_version': 1, 'generation_id': generation}),
            201,
          );
        }
        return http.Response('', 204);
      }),
    );
    final client = ScreenPreviewClient(api.transport);
    final resolved = await client.begin(lease);
    await client.invalidate(lease, resolved);

    expect(requests.map((request) => request.method), ['POST', 'DELETE']);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/voice/leases/$lease/screen-previews/v1',
      '/api/v1/voice/leases/$lease/screen-previews/v1/$generation',
    ]);
    expect(
      requests.every(
        (request) => request.headers['cookie'] == 'session=preview-test',
      ),
      isTrue,
    );
  });

  test(
    'sender refreshes only the server-owned capture lease every 30 seconds',
    () async {
      const lease = 'd9428888-122b-4a50-8c5c-5b9393a4e5f1';
      const generation = 'e35d15a4-6d8c-4a6e-a6b9-78de899631f8';
      var now = DateTime.utc(2026, 10, 29);
      var begins = 0;
      final methods = <String>[];
      final api = ApiClient(
        client: MockClient((request) async {
          methods.add(request.method);
          if (request.method == 'POST') {
            begins++;
            return http.Response(
              jsonEncode({'schema_version': 1, 'generation_id': generation}),
              201,
            );
          }
          return http.Response('', 204);
        }),
      );
      final sender = LatestScreenPreviewUploader(
        ScreenPreviewClient(api.transport),
        now: () => now,
        refreshInterval: const Duration(milliseconds: 10),
      );

      await sender.start(lease);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(begins, 1);
      now = now.add(const Duration(milliseconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(begins, 2);
      await sender.stop();

      expect(methods, ['POST', 'POST', 'DELETE']);
    },
  );
}
