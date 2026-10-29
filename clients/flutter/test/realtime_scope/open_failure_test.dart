import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

class OpeningFailureApi extends RealtimeApiFake {
  @override
  Future<WebSocket> openRealtime({String? after}) async {
    opens++;
    throw const SocketException('synthetic owned connection failure');
  }
}

void main() {
  testWidgets('socket-open failures keep one bounded automatic retry', (
    tester,
  ) async {
    final api = OpeningFailureApi();
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
      jitter: () => 0,
    );
    addTearDown(owner.dispose);
    await owner.connect();
    expect(api.opens, 1);
    expect(owner.connecting, isFalse);
    expect(owner.retry?.isActive, isTrue);
    expect(owner.attempt, 1);
    await tester.pump(const Duration(milliseconds: 499));
    expect(api.opens, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(api.opens, 2);
    expect(owner.retry?.isActive, isTrue);
    expect(owner.attempt, 2);
    await tester.pump(const Duration(milliseconds: 999));
    expect(api.opens, 2);
    await owner.close();
  });

  test('late failed open cannot revive a closed session scope', () async {
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
    final pending = owner.connect();
    scope.close();
    await owner.close();
    api.opening.completeError(const SocketException('late owned failure'));
    await pending;
    expect(owner.retry, isNull);
    expect(api.opens, 1);
    expect(owner.connecting, isFalse);
  });
}
