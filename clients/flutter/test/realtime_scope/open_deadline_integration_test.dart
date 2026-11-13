import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class DeadlineLoopbackApi extends ApiClient {
  DeadlineLoopbackApi(this.endpoint);
  final String endpoint;
  int opens = 0;

  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) {
    opens++;
    return WebSocket.connect(endpoint, customClient: client);
  }

  @override
  Future<SessionUser?> currentSession() async =>
      const SessionUser(accountId: 'owned-local', role: 'MEMBER');
}

class RealHttpOverrides extends HttpOverrides {}

void main() {
  test('hung upgrade closes the TCP connection and reconnects', () async {
    final elapsed = Stopwatch()..start();
    await HttpOverrides.runWithHttpOverrides<Future<void>>(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final api = DeadlineLoopbackApi('ws://127.0.0.1:${server.port}/owned');
      final owner = RealtimeController(
        api,
        SessionScope(),
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
        jitter: () => 0,
      );
      final disconnected = Completer<void>();
      final ready = Completer<void>();
      final held = <Socket>[];
      final sockets = <WebSocket>[];
      var requests = 0;
      owner.addListener(() {
        if (owner.connected && !ready.isCompleted) ready.complete();
      });
      final listener = server.listen((request) async {
        requests++;
        if (requests == 1) {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          held.add(socket);
          socket.listen(
            (_) {},
            onDone: () {
              if (!disconnected.isCompleted) disconnected.complete();
            },
          );
        } else {
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
        await disconnected.future.timeout(const Duration(seconds: 4));
        await ready.future.timeout(const Duration(seconds: 10));
        expect(requests, 2);
        expect(api.opens, 2);
        expect(owner.connected, isTrue);
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(owner.connected, isTrue);
      } finally {
        await owner.close();
        owner.dispose();
        for (final socket in held) {
          socket.destroy();
        }
        for (final socket in sockets) {
          await socket.close();
        }
        await listener.cancel();
        await server.close(force: true);
      }
    }, RealHttpOverrides());
    expect(elapsed.elapsed, greaterThanOrEqualTo(const Duration(seconds: 15)));
  }, timeout: const Timeout(Duration(seconds: 35)));
}
