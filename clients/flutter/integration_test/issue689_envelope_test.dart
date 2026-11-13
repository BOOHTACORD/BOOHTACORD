import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class EnvelopeLoopbackApi extends ApiClient {
  EnvelopeLoopbackApi(this.endpoint);
  final String endpoint;
  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) =>
      WebSocket.connect(endpoint);
  @override
  Future<SessionUser?> currentRealtimeSession(
    Future<void> abort,
    bool Function() current,
  ) async => const SessionUser(accountId: 'local', role: 'MEMBER');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native client reconnects after malformed maintenance envelope', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[], again = Completer<void>();
      const id = '11111111-1111-4111-8111-111111111111';
      final requests = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.add(
          jsonEncode({
            'event_id': id,
            'kind': 'connection.ready',
            'occurred_at': '2026-11-13T00:00:00Z',
            'payload': {},
          }),
        );
        if (sockets.length == 1) {
          socket.add(
            jsonEncode({
              'event_id': id,
              'kind': 'maintenance.snapshot',
              'occurred_at': '2026-11-13T00:00:00Z',
              'unexpected': true,
              'payload': {
                'version': 1,
                'generation': id,
                'revision': 1,
                'active': false,
              },
            }),
          );
        } else if (!again.isCompleted) {
          again.complete();
        }
      });
      final api = EnvelopeLoopbackApi('ws://127.0.0.1:${server.port}/realtime');
      final owner = RealtimeController(
        api,
        SessionScope(),
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
        jitter: () => 0,
      );
      try {
        await owner.connect();
        await again.future.timeout(const Duration(seconds: 10));
        expect(sockets.length, 2);
      } finally {
        await owner.close();
        owner.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await requests.cancel();
        await server.close(force: true);
      }
    });
  }, timeout: const Timeout(Duration(seconds: 20)));
}
