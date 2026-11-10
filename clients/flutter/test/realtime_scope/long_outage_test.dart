import 'dart:convert';
import 'dart:io';

import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class OutageApi extends ApiClient {
  int opens = 0;
  final socket = SocketFake();

  @override
  Future<WebSocket> openRealtime({String? after}) {
    opens++;
    if (opens <= 9) return Future.error(const SocketException('offline'));
    return Future.value(socket);
  }
}

void main() {
  testWidgets('long outage continues one retry and recovers', (tester) async {
    final api = OutageApi();
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
    const delays = [500, 1000, 2000, 4000, 8000, 15000, 15000, 15000, 15000];
    for (var attempt = 0; attempt < delays.length; attempt++) {
      expect(owner.retry?.isActive, isTrue);
      final pending = owner.retry;
      owner.scheduleRetry();
      expect(owner.retry, same(pending));
      await tester.pump(Duration(milliseconds: delays[attempt]));
      await tester.pump();
      expect(api.opens, attempt + 2);
    }
    expect(owner.socket, same(api.socket));
    owner.receive(jsonEncode({
      'event_id': 'ready',
      'kind': 'connection.ready',
      'payload': {},
    }));
    expect(owner.connected, isTrue);
    expect(owner.attempt, 0);
    expect(owner.retry, isNull);
  });
}
