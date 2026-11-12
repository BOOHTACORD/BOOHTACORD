import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'fakes.dart';

class ReconnectApi extends ApiClient {
  final sockets = <SocketFake>[];
  final cursors = <String?>[];
  final sessionCheck = Completer<SessionUser?>();
  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) async {
    cursors.add(after);
    final socket = SocketFake();
    sockets.add(socket);
    return socket;
  }

  @override
  Future<SessionUser?> currentSession() => sessionCheck.future;
}

class DelayedReconnectApi extends ApiClient {
  final openings = <Completer<WebSocket>>[];
  @override
  Future<WebSocket> openRealtime({String? after, HttpClient? client}) {
    final opening = Completer<WebSocket>();
    openings.add(opening);
    return opening.future;
  }
}

void main() {
  test(
    'manual reconnect closes the old socket and keeps the replay cursor',
    () async {
      final api = ReconnectApi();
      final owner = RealtimeController(
        api,
        SessionScope(),
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(owner.dispose);
      owner.synchronizeDeliveryScope();
      owner.delivery.accept(
        const RealtimeEvent('cursor', 'message.created', {}),
      );
      await Future<void>.delayed(Duration.zero);
      await owner.connect();
      await owner.reconnectNow();
      expect(api.sockets, hasLength(2));
      expect(api.sockets.first.closed, isTrue);
      expect(api.cursors.last, 'cursor');
      expect(owner.socket, same(api.sockets.last));
      await owner.close();
    },
  );

  test(
    'late session check from the old connection cannot expire a replacement',
    () async {
      final api = ReconnectApi();
      var expired = false;
      final owner = RealtimeController(
        api,
        SessionScope(),
        isReady: () => true,
        expire: () async {
          expired = true;
        },
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(owner.dispose);
      await owner.connect();
      owner.handleClosed();
      await owner.reconnectNow();
      api.sessionCheck.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(expired, isFalse);
      expect(owner.socket, same(api.sockets.last));
      expect(api.sockets, hasLength(2));
      await owner.close();
    },
  );

  test('late open from a replaced attempt is closed and cannot replace the new socket', () async {
    final api = DelayedReconnectApi();
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
    );
    addTearDown(owner.dispose);
    final first = owner.connect();
    final replacement = owner.reconnectNow();
    await Future<void>.delayed(Duration.zero);
    expect(api.openings, hasLength(2));
    final oldSocket = SocketFake(), newSocket = SocketFake();
    api.openings[1].complete(newSocket);
    await replacement;
    api.openings[0].complete(oldSocket);
    await first;
    expect(oldSocket.closed, isTrue);
    expect(owner.socket, same(newSocket));
    await owner.close();
  });
}
