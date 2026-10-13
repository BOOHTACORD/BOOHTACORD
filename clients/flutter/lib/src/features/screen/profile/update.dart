import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../capture/confirmed_dimensions.dart';
import 'quality.dart';
import '../rollout/policy.dart';
import '../rollout/publish_plan.dart';

Future<bool> updateScreenShareProfile(
  Room room,
  LocalVideoTrack track,
  ScreenShareQuality quality,
  VideoDimensions? dimensions,
  bool Function() isCurrent, {
  Future<Map<String, dynamic>> Function(String)? readSnapshot,
}) async {
  if (!isCurrent()) return false;
  final participant = room.localParticipant;
  if (participant == null) throw StateError('Голосовое подключение закрыто.');
  final previous = track.lastPublishOptions;
  if (previous == null) throw StateError('Профиль демонстрации недоступен.');
  final confirmedDimensions = await readScreenCaptureDimensions(
    track,
    platform: defaultTargetPlatform,
    isCurrent: isCurrent,
    readSnapshot: readSnapshot,
  );
  if (!isCurrent()) return false;
  final source =
      confirmedDimensions ??
      (defaultTargetPlatform == TargetPlatform.windows ? dimensions : null);
  final profile = nativeScreenPublishPlan(
    quality,
    ScreenMediaRollout(boundedSimulcast: previous.simulcast),
    defaultTargetPlatform,
    sourceDimensions: source,
  );
  final publication = await participant.updateScreenShareTrackProfile(
    track,
    publishOptions: previous.copyWith(
      name: profile.name,
      screenShareEncoding: profile.screenShareEncoding,
      degradationPreference: profile.degradationPreference,
      screenShareSimulcastLayers: profile.screenShareSimulcastLayers,
      backupVideoCodec: profile.backupVideoCodec,
    ),
    isCurrent: isCurrent,
  );
  return publication != null && isCurrent();
}
