import 'dart:async';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';
export 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';

class RosterHarness {
  RosterHarness() {
    owner = VoiceRosterController(
      SessionScope(),
      isReady: () => true,
      hasUser: () => true,
      onSharedRetry: () => retries++,
    );
  }
  late final VoiceRosterController owner;
  int retries = 0;
}

class RosterApi extends ApiClient {
  int rosterReads = 0;
  @override
  Future<List<VoiceRoomRoster>> voiceParticipants() {
    rosterReads++;
    throw StateError('Unexpected roster polling');
  }
}

class ScheduledRosterTimer implements Timer {
  ScheduledRosterTimer(this.delay, this.callback);
  final Duration delay;
  final void Function() callback;
  bool active = true;
  void fire() {
    if (active) {
      active = false;
      callback();
    }
  }

  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => active ? 0 : 1;
}
