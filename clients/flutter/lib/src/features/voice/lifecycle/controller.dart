import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'state.dart';
import '../screen_preview/receive.dart';
import '../shortcuts/execute.dart';
import '../connection_close/leave.dart';
import '../volumes/reset.dart';
import '../connection_stats/poll.dart';
import '../stream_notice/events.dart';
import '../background_microphone/session.dart';
import '../background_microphone/admission.dart';
export 'types.dart';
export '../shortcuts/execute.dart';
export '../preferences/shortcuts.dart';
export '../disconnect_notice/control.dart';
export '../stream_notice/preferences.dart';
export '../stream_notice/events.dart';
export '../preferences/load.dart';
export '../microphone/mode.dart';
export '../microphone/ptt.dart';
export '../microphone/capture.dart';
export '../microphone/deafen.dart';
export '../lease_events/revocation.dart';
export '../admission/join.dart';
export '../room_events/bind.dart';
export '../remote_tracks/subscriptions.dart';
export '../screen_viewer/selection.dart';
export '../screen_viewer/subscription.dart';
export '../screen_viewer/recovery_foreground.dart';
export '../screen_viewer/recovery_manual.dart';
export '../screen_viewer/subscription_recovery.dart';
export '../screen_preview/capture.dart';
export '../screen_preview/receive.dart';
export '../connection_stats/poll.dart';
export '../volumes/read.dart';
export '../volumes/mute.dart';
export '../volumes/change.dart';
export '../volumes/apply.dart';
export '../volumes/reset.dart';
export '../connection_close/disconnect.dart';
export '../connection_close/leave.dart';

class VoiceController extends VoiceState {
  VoiceController(
    super.api,
    super.scope,
    super.audio,
    super.screen, {
    required super.readUser,
    required super.reportError,
    required super.formatError,
    Room Function(RoomOptions)? roomFactory,
    Future<void> Function(Room, MediaDevice)? audioOutputDeviceSetter,
    MicrophoneForegroundSession? microphoneForeground,
  }) : audioOutputDeviceSetter =
           audioOutputDeviceSetter ??
           ((room, device) => room.setAudioOutputDevice(device)),
       microphoneForeground =
           microphoneForeground ?? MicrophoneForegroundSession(),
       super(
         createRoom: roomFactory ?? ((options) => Room(roomOptions: options)),
       ) {
    this.microphoneForeground.onStopped = backgroundMicrophoneStopped;
  }
  final MicrophoneForegroundSession microphoneForeground;
  final Future<void> Function(Room, MediaDevice) audioOutputDeviceSetter;
  final Map<String, RemoteTrackPublication> screenThumbnailPublications = {};
  static const voiceStreamSoundPreferenceKey = 'voice-screen-start-sound:v1';
  @override
  void dispose() {
    unawaited(microphoneForeground.dispose());
    unawaited(flushVoiceVolumes());
    cancelVoiceShortcuts(release: true);
    disconnect.reset();
    disposed = true;
    operationRevision++;
    unawaited(screenViewerPresence.clear());
    clearScreenPreviewReceivers();
    remoteScreenViewerRecoveryTimer?.cancel();
    remoteScreenViewerRecoveryTimer = null;
    remoteScreenViewerRecoveryDeadline.reset();
    remoteScreenViewerRecoveryAttempt = 0;
    remoteScreenViewerRecoveryInFlightGeneration = null;
    remoteScreenViewerRecoveryPublication = null;
    remoteScreenViewerRecoveryIsCurrent = null;
    selectedRemoteScreenViewerIdentity = null;
    screenThumbnails.clear();
    screenThumbnailPublications.clear();
    stopVoiceConnectionStatsPolling();
    clearVoiceStreamNotice(resetTracker: true, notify: false);
    unawaited(disposeVoiceEvents());
    unawaited(room?.disconnect());
    unawaited(pendingRoom?.disconnect());
    super.dispose();
  }
}
