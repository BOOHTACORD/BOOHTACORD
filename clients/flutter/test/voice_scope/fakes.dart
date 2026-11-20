import 'dart:async';

import 'package:livekit_client/livekit_client.dart';
import 'package:boohtacord_desktop/src/core/session/scope.dart';
import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/features/screen/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/background_microphone/session.dart';
import 'package:boohtacord_desktop/src/features/voice/background_playback/session.dart';
import 'package:boohtacord_desktop/src/models.dart';

import 'api.dart';
import 'pending_room_fake.dart';

export 'pending_room_fake.dart';

class VoiceHarness {
  VoiceHarness({
    Future<void> Function()? nativeBootstrap,
    this.account,
    MicrophoneForegroundSession? foreground,
    VoicePlaybackForegroundSession? playbackForeground,
  }) {
    audio = AudioDeviceController(
      readRoom: () => owner.room,
      loader: () async {
        audioScans++;
        return enumeratedDevices;
      },
      nativeBootstrap: nativeBootstrap,
    );
    screen = ScreenShareController(
      api,
      scope,
      readRoom: () => owner.room,
      voiceReady: () => true,
    );
    owner = VoiceController(
      api,
      scope,
      audio,
      screen,
      readUser: () => account,
      reportError: (value) => error = value,
      formatError: (value) => value.toString(),
      microphoneForeground: foreground,
      voicePlaybackForeground: playbackForeground,
      roomFactory: (options) {
        created++;
        createdRoomOptions = options;
        room.roomOptions = options;
        return room;
      },
      audioOutputDeviceSetter: (candidate, device) async {
        if (candidate is PendingVoiceRoom) candidate.selectedOutput = device;
      },
    );
  }
  final api = DelayedVoiceApi();
  final scope = SessionScope();
  final room = PendingVoiceRoom();
  final SessionUser? account;
  List<MediaDevice> enumeratedDevices = const [];
  late final AudioDeviceController audio;
  late final ScreenShareController screen;
  late final VoiceController owner;
  int created = 0;
  RoomOptions? createdRoomOptions;
  int audioScans = 0;
  String? error;
  Future<void> dispose() async {
    owner.dispose();
    screen.dispose();
    audio.dispose();
    await room.events.dispose();
  }
}
