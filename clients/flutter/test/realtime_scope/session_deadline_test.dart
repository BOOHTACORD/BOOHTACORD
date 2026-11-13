import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class RetryCheckApi extends RealtimeApiFake {
  @override
  Future<SocketFake> openRealtime({String? after, HttpClient? client}) async {
    opens++;
    return SocketFake();
  }
}

void main() {
  testWidgets('stalled session check times out and ignores late expiration', (
    tester,
  ) async {
    final api = RealtimeApiFake();
    var expirations = 0;
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {
        expirations++;
      },
      invalidatePresence: () {},
      dispatch: (_) {},
      jitter: () => 0,
    );
    addTearDown(owner.dispose);
    final socket = SocketFake();
    api.opening.complete(socket);
    final first = owner.connect();
    await tester.pump();
    await first;
    await socket.close();
    await tester.pump();
    expect(owner.checkingSession, isTrue);
    var aborted = false;
    api.abortSignal!.then((_) => aborted = true);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(owner.checkingSession, isFalse);
    expect(aborted, isTrue);
    expect(owner.retry?.isActive, isTrue);
    api.restored.complete(null);
    await tester.pump();
    expect(expirations, 0);
    await owner.close();
  });

  test('manual retry aborts the old session check', () async {
    final api = RetryCheckApi();
    var expirations = 0;
    final owner = RealtimeController(
      api,
      SessionScope(),
      isReady: () => true,
      expire: () async {
        expirations++;
      },
      invalidatePresence: () {},
      dispatch: (_) {},
      jitter: () => 0,
    );
    addTearDown(owner.dispose);
    await owner.connect();
    owner.handleClosed();
    await Future<void>.delayed(Duration.zero);
    var aborted = false;
    api.abortSignal!.then((_) => aborted = true);
    owner.retryNow();
    await Future<void>.delayed(Duration.zero);
    expect(aborted, isTrue);
    api.restored.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(expirations, 0);
    expect(api.opens, 2);
    await owner.close();
  });
}
