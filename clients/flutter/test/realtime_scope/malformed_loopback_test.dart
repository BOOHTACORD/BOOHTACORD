import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class LoopbackApi extends ApiClient {
  LoopbackApi(this.endpoint);
  final String endpoint;
  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) => WebSocket.connect(endpoint);
  @override
  Future<SessionUser?> currentRealtimeSession(Future<void> abort, bool Function() current) async =>
      const SessionUser(accountId: 'local', role: 'MEMBER');
}

void main() {
  for (final invalid in <Object>['{"kind":', <int>[1, 2]]) {
    test('real socket reconnects after a malformed frame', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[], reconnected = Completer<void>();
      final requests = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.add(jsonEncode({'event_id': 'ready', 'kind': 'connection.ready', 'payload': {}}));
        if (sockets.length == 1) {
          socket.add(invalid);
        } else if (!reconnected.isCompleted) {
          reconnected.complete();
        }
      });
      final api = LoopbackApi('ws://127.0.0.1:${server.port}/realtime');
      final owner = RealtimeController(api, SessionScope(), isReady: () => true,
          expire: () async {}, invalidatePresence: () {}, dispatch: (_) {}, jitter: () => 0);
      try {
        await owner.connect();
        await reconnected.future.timeout(const Duration(seconds: 10));
        expect(sockets, hasLength(2));
      } finally {
        await owner.close();
        owner.dispose();
        for (final socket in sockets) { await socket.close(); }
        await requests.cancel();
        await server.close(force: true);
      }
    });
  }
}
