import 'package:flutter_test/flutter_test.dart';

import '../../../../tools/audio/windows_auto_probe/receiver_mute.dart';

void main() {
  test(
    'every replacement receiver track is muted after initial readiness',
    () async {
      final calls = <int>[];
      final guard = ReceiverMute<int>((track) async {
        calls.add(track);
      });
      await guard.apply(1);
      await guard.ready.future;
      await guard.apply(2);
      expect(calls, [1, 2]);
      expect(guard.failed, false);
    },
  );
  test(
    'a later mute failure cannot turn an earlier success into a pass',
    () async {
      final guard = ReceiverMute<int>((track) async {
        if (track == 2) throw StateError('mute');
      });
      await guard.apply(1);
      await guard.ready.future;
      await guard.apply(2);
      expect(guard.failed, true);
    },
  );
  test('initial mute failure reaches the readiness waiter', () async {
    final guard = ReceiverMute<int>((_) async {
      throw StateError('mute');
    });
    final rejected = expectLater(guard.ready.future, throwsStateError);
    await guard.apply(1);
    await rejected;
    expect(guard.failed, true);
  });
}
