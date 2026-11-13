import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/liveness.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class HeartbeatApi extends ApiClient {
  HeartbeatApi(this.endpoint);
  final String endpoint;
  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) =>
      WebSocket.connect(endpoint, protocols: [heartbeatProtocol]);
  @override
  Future<SessionUser?> currentRealtimeSession(
    Future<void> abort,
    bool Function() current,
  ) async => const SessionUser(accountId: 'local', role: 'MEMBER');
}

String event(String kind) => jsonEncode({
  'event_id': '11111111-1111-4111-8111-111111111111',
  'kind': kind,
  'occurred_at': '2026-11-13T00:00:00Z',
  'payload': {},
});

void main() {
  test('negotiated real socket reconnects after silent peer', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final again = Completer<void>();
    final requests = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) =>
            protocols.contains(heartbeatProtocol) ? heartbeatProtocol : null,
      );
      sockets.add(socket);
      socket.add(event('connection.ready'));
      socket.add(event('connection.heartbeat'));
      if (sockets.length == 2 && !again.isCompleted) again.complete();
    });
    final api = HeartbeatApi('ws://127.0.0.1:${server.port}/realtime');
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
      await again.future.timeout(const Duration(seconds: 58));
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
  }, timeout: const Timeout(Duration(seconds: 65)));
}
