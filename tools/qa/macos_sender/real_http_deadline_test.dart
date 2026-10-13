import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';

class LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real IO transport deadline keeps timeout classification', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final pending = <HttpRequest>[];
    final subscription = server.listen(pending.add);
    final api = ApiClient(
      client: IOClient(
        HttpOverrides.runWithHttpOverrides(
          () => HttpClient(),
          LoopbackHttpOverrides(),
        )!..findProxy = (_) => 'DIRECT',
      ),
    )..baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
    try {
      for (var i = 0; i < 5; i++) {
        await expectLater(
          api.reportScreenShareMetrics(const {
            'platform': 'macos_native',
            'direction': 'sender',
            'state': 'waiting_first_frame',
          }, timeout: const Duration(milliseconds: 100)),
          throwsA(isA<TimeoutException>()),
        );
      }
    } finally {
      api.transport.raw.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
