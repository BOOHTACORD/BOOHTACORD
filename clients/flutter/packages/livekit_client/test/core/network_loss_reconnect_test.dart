import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/internal/events.dart';

import '../mock/e2e_container.dart';
import '../mock/peerconnection_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late E2EContainer container;
  late Room room;

  setUp(() async {
    resetMockDataChannels();
    container = E2EContainer();
    room = container.room;
    await container.connectRoom();
  });

  tearDown(() async => container.dispose());

  test('loss of every network makes the room enter recovery once', () async {
    final events = <RoomEvent>[];
    final cancel = room.events.listen(events.add);
    const loss = SignalConnectivityChangedEvent(
      oldState: [ConnectivityResult.wifi],
      state: [ConnectivityResult.none],
    );
    container.engine.signalClient.events.emit(loss);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.engine.signalClient.events.emit(loss);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(events.whereType<RoomResumingEvent>(), hasLength(1));
    expect(container.engine.isPendingReconnect, isTrue);
    await cancel();
  });

  test('a change between available networks does not force recovery', () async {
    final events = <RoomEvent>[];
    final cancel = room.events.listen(events.add);
    container.engine.signalClient.events.emit(
      const SignalConnectivityChangedEvent(
        oldState: [ConnectivityResult.wifi],
        state: [ConnectivityResult.mobile],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(events.whereType<RoomResumingEvent>(), isEmpty);
    expect(container.engine.isPendingReconnect, isFalse);
    await cancel();
  });

  test('network loss after explicit disconnect does not restart voice', () async {
    // The socket mock does not send a server leave acknowledgement.
    await container.engine.disconnect();
    expect(container.engine.isClosed, isTrue);
    final events = <RoomEvent>[];
    final cancel = room.events.listen(events.add);
    container.engine.signalClient.events.emit(
      const SignalConnectivityChangedEvent(
        oldState: [ConnectivityResult.wifi],
        state: [ConnectivityResult.none],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(events.whereType<RoomResumingEvent>(), isEmpty);
    expect(container.engine.isPendingReconnect, isFalse);
    await cancel();
  });
}
