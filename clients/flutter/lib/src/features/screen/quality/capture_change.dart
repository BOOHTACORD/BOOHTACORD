import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../lifecycle/controller.dart';
import '../profile/quality.dart';

Future<void> applyCaptureProfileChange(
  ScreenShareController owner,
  ScreenShareQuality requested,
) async {
  ScreenShareCaptureOptions? options;
  if (defaultTargetPlatform == TargetPlatform.windows) {
    try {
      final current = owner.activeTrack?.currentOptions;
      if (current is ScreenShareCaptureOptions) options = current;
    } catch (_) {
      // An unknown source must never silently switch to another window.
    }
  }
  final source = options?.deviceId;
  if (source == null || source.isEmpty) {
    owner.captureRestartRequired = true;
    owner.error =
        'Чтобы применить ${requested.resolution}p${requested.frameRate}, '
        'остановите демонстрацию и запустите её снова, выбрав этот профиль. '
        'Текущая демонстрация продолжает работать с прежними параметрами.';
    owner.changed();
    return;
  }
  final room = owner.readRoom();
  final ticket = owner.scope.capture();
  final transport = owner.api.transport.session.scope.capture();
  final server = owner.api.transport.session.serverRevision;
  final revision = owner.revision + 1;
  final intent = owner.qualityIntentRevision + 1;
  final dimensions = owner.sourceDimensions;
  final mode = owner.contentMode;
  await owner.stopScreenShare();
  if (room == null ||
      !owner.current(ticket, revision, room) ||
      !transport.isActive ||
      server != owner.api.transport.session.serverRevision ||
      intent != owner.qualityIntentRevision ||
      owner.phase != ScreenSharePhase.idle ||
      !owner.voiceReady()) {
    return;
  }
  await owner.startScreenShare(
    sourceId: source,
    quality: requested,
    sourceDimensions: dimensions,
    contentMode: mode,
    captureScreenAudio: options!.captureScreenAudio,
    retainUserQuality: true,
  );
}
