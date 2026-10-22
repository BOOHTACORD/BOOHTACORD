import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

void main() {
  test(
    'socket open does not reset attempts; only protocol-ready does',
    () async {
      final api = RealtimeApiFake(), scope = SessionScope();
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
        jitter: () => 0.5,
      );
      addTearDown(owner.dispose);
      owner.attempt = 4;
      api.opening.complete(SocketFake());
      await owner.connect();
      expect(owner.attempt, 4);
      owner.receive(
        jsonEncode({
          'event_id': 'ready',
          'kind': 'connection.ready',
          'payload': {},
        }),
      );
      expect(owner.attempt, 0);
      expect(owner.readyTimeout?.isActive ?? false, isFalse);
    },
  );
  testWidgets(
    'jittered retry grows before ready and manual retry cancels timer',
    (tester) async {
      final api = RealtimeApiFake(), scope = SessionScope();
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
        jitter: () => 0,
      );
      addTearDown(owner.dispose);
      owner.attempt = 2;
      owner.scheduleRetry();
      expect(owner.attempt, 3);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(api.opens, 0);
      owner.retryNow();
      expect(api.opens, 1);
      expect(owner.retry, isNull);
      await tester.pump(const Duration(seconds: 35));
      expect(api.opens, 1);
      await owner.close();
      expect(owner.attempt, 0);
    },
  );
  test(
    'reconnect passes the last applied durable cursor into the socket API',
    () async {
      final api = RealtimeApiFake(), scope = SessionScope();
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(owner.dispose);
      owner.synchronizeDeliveryScope();
      owner.delivery.accept(
        const RealtimeEvent('cursor', 'message.updated', {}),
      );
      await Future<void>.delayed(Duration.zero);
      api.opening.complete(SocketFake());
      await owner.connect();
      expect(api.after, 'cursor');
    },
  );
  test(
    'new account, server or installation cannot reuse replay cursor',
    () async {
      final api = RealtimeApiFake(), scope = SessionScope();
      final owner = RealtimeController(
        api,
        scope,
        isReady: () => true,
        expire: () async {},
        invalidatePresence: () {},
        dispatch: (_) {},
      );
      addTearDown(owner.dispose);
      owner.synchronizeDeliveryScope();
      owner.delivery.accept(
        const RealtimeEvent('applied', 'message.created', {}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(owner.delivery.cursor, 'applied');
      scope.close();
      scope.begin();
      owner.synchronizeDeliveryScope();
      expect(owner.delivery.cursor, isNull);
      owner.delivery.accept(
        const RealtimeEvent('server', 'message.created', {}),
      );
      await Future<void>.delayed(Duration.zero);
      api.transport.session.telemetry.bindInstallation(
        '11111111-1111-4111-8111-111111111111',
      );
      owner.synchronizeDeliveryScope();
      expect(owner.delivery.cursor, isNull);
      owner.delivery.accept(const RealtimeEvent('new', 'message.created', {}));
      await Future<void>.delayed(Duration.zero);
      api.transport.session.baseUrl = 'https://another.example/api/v1';
      owner.synchronizeDeliveryScope();
      expect(owner.delivery.cursor, isNull);
    },
  );
}
