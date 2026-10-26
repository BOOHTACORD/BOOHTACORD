import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support.dart';
import 'app_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AppState clears initial failure only after a replacement snapshot',
    () async {
      final api = RosterApi();
      final state = ready(api);
      state.voiceRoster.start();
      api.streams.single.completeError(
        const ApiFailure('unavailable', status: 503),
      );
      await flush();
      expect(state.voiceRosterError, isNotNull);
      expect(state.voiceRosters, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final stream = await connect(api);
      stream.add(utf8.encode('data: {"channels":[]}\n\n'));
      await flush();
      expect(state.voiceRosterError, isNull);
      expect(state.voiceRosters, isEmpty);
      expect(state.voiceRoster.phase, VoiceRosterPhase.fresh);
      expect(state.voiceRoster.lastUpdatedAt, isNotNull);
      state.voiceRoster.stop();
      expect(state.voiceRoster.lastUpdatedAt, isNull);
      await stream.close();
    },
  );

  test(
    'AppState announces stale immediately and expires after its timeout',
    () async {
      final api = RosterApi();
      final state = ready(api);
      state.voiceRoster.start();
      final stream = await connect(api);
      stream.add(
        utf8.encode(
          'data: {"channels":[{"channel_id":"voice-channel","participants":[]}]}\n\n',
        ),
      );
      await flush();
      expect(state.voiceRosters, hasLength(1));
      final expired = Completer<void>();
      state.addListener(() {
        if (state.voiceRoster.phase == VoiceRosterPhase.unavailable &&
            !expired.isCompleted) {
          expired.complete();
        }
      });
      await stream.close();
      await flush();
      expect(state.voiceRoster.phase, VoiceRosterPhase.stale);
      expect(state.voiceRosterError, isNotNull);
      expect(state.voiceRosters, hasLength(1));
      await expired.future.timeout(const Duration(seconds: 2));
      expect(state.voiceRosters, isNull);
    },
  );

  test(
    'AppState recovery cancels stale expiry while the replacement stays open',
    () async {
      final api = RosterApi();
      final state = ready(api);
      state.voiceRoster.start();
      final first = await connect(api);
      first.add(utf8.encode('data: {"channels":[]}\n\n'));
      await flush();
      await first.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final recovered = await connect(api);
      recovered.add(
        utf8.encode(
          'data: {"channels":[{"channel_id":"voice-channel","participants":[]}]}\n\n',
        ),
      );
      await flush();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(state.voiceRosters, hasLength(1));
      expect(state.voiceRosterError, isNull);
      expect(state.voiceRoster.phase, VoiceRosterPhase.fresh);
      state.voiceRoster.stop();
      await recovered.close();
    },
  );
}
