import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class LoopbackSocketApi extends ApiClient {
  LoopbackSocketApi(this.endpoint);
  final String endpoint;
  int opens = 0;
  @override
  Future<WebSocket> openRealtime({String? after}) {
    opens++;
    return WebSocket.connect(endpoint);
  }

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'owned-local', role: 'MEMBER');
}

void main() {
  test(
    'real failed HTTP handshake recovers to protocol-ready automatically',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final statuses = <int>[];
      final ready = Completer<void>();
      final api = LoopbackSocketApi('ws://127.0.0.1:${server.port}/owned');
      final owner = RealtimeController(
        api,
        SessionScope(),
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
        jitter: () => 0,
      );
      owner.addListener(() {
        if (owner.connected && !ready.isCompleted) ready.complete();
      });
      final requests = server.listen((request) async {
        expect(request.uri.path, '/owned');
        if (statuses.isEmpty) {
          statuses.add(503);
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
        } else {
          statuses.add(101);
          final socket = await WebSocketTransformer.upgrade(request);
          sockets.add(socket);
          socket.add(
            jsonEncode({
              'event_id': 'ready',
              'kind': 'connection.ready',
              'payload': {},
            }),
          );
        }
      });
      try {
        await owner.connect();
        expect(owner.connecting, isFalse);
        expect(owner.retry?.isActive, isTrue);
        await ready.future.timeout(const Duration(seconds: 10));
        expect(statuses, [503, 101]);
        expect(api.opens, 2);
        expect(owner.connected, isTrue);
        expect(owner.attempt, 0);
        expect(owner.retry, isNull);
        expect(owner.readyTimeout?.isActive ?? false, isFalse);
      } finally {
        await owner.close();
        owner.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await requests.cancel();
        await server.close(force: true);
      }
    },
  );
}
