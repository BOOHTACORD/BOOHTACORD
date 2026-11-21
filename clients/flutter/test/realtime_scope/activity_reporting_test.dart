import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';

import 'fakes.dart';

class RecordingSocket extends SocketFake {
  final messages = <Map<String, dynamic>>[];
  @override
  void add(dynamic data) =>
      messages.add(jsonDecode(data as String) as Map<String, dynamic>);
}

void main() {
  test('activity and inactivity contain no identifiers and inactivity is once per connection', () {
    final owner = RealtimeController(
      RealtimeApiFake(),
      SessionScope(),
      isReady: () => true,
      expire: () async {},
      invalidatePresence: () {},
      dispatch: (_) {},
    );
    addTearDown(owner.dispose);
    final first = RecordingSocket(), second = RecordingSocket();
    owner.socket = first;
    owner.connected = true;
    owner.reportInactive();
    owner.reportInactive();
    owner.reportActivity();
    expect(first.messages, [
      {'type': 'inactive'},
      {'type': 'activity'},
    ]);
    owner.socket = second;
    owner.reportInactive();
    owner.reportInactive();
    expect(second.messages, [
      {'type': 'inactive'},
    ]);
  });
}
