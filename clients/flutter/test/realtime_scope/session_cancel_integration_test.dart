import 'dart:async';
import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class RealHttpOverrides extends HttpOverrides {}

class LoopbackSessionApi extends ApiClient {
  final socket = SocketFake();
  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) async =>
      socket;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'closing the owner aborts a stalled real session HTTP request',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      await HttpOverrides.runWithHttpOverrides<Future<void>>(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final api = LoopbackSessionApi()
          ..baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
        final owner = RealtimeController(
          api,
          SessionScope(),
          isReady: () => true,
          expire: () async {},
          invalidatePresence: () {},
          dispatch: (_) {},
        );
        final received = Completer<void>(), disconnected = Completer<void>();
        final sockets = <Socket>[];
        final listener = server.listen((request) async {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          sockets.add(socket);
          socket.listen((_) {}, onDone: () => disconnected.complete());
          received.complete();
        });
        try {
          await owner.connect();
          await api.socket.close();
          await received.future.timeout(const Duration(seconds: 5));
          await owner.close();
          await disconnected.future.timeout(const Duration(seconds: 5));
          expect(owner.retry, isNull);
        } finally {
          await owner.close();
          owner.dispose();
          api.transport.raw.close();
          for (final socket in sockets) {
            socket.destroy();
          }
          await listener.cancel();
          await server.close(force: true);
        }
      }, RealHttpOverrides());
    },
  );
}
