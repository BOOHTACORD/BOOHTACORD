import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../profile/quality.dart';
import '../profile/update.dart';
import 'android.dart';
import 'audio_track_registry.dart';
import 'dimensions.dart';
import '../rollout/policy.dart';
import '../rollout/publish_plan.dart';

abstract class ScreenShareDriver {
  Future<void> prepare(bool Function() active);
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options);
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  );
  Future<bool> updateQuality(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
    bool Function() isCurrent,
  );
  Future<void> discard(Room room, LocalVideoTrack track);
  Future<void> stop(Room room);
  Future<void> disableBackground();
}

@visibleForTesting
ScreenShareCaptureOptions nativeScreenCaptureOptions(
  ScreenShareCaptureOptions options,
  TargetPlatform platform,
) => options.copyWith(
  useiOSBroadcastExtension:
      platform == TargetPlatform.iOS && options.captureScreenAudio,
);

class NativeScreenShareDriver implements ScreenShareDriver {
  NativeScreenShareDriver({this.rollout = const ScreenMediaRollout()});
  final ScreenMediaRollout rollout;
  final ScreenAudioTrackRegistry _screenAudioTracks =
      ScreenAudioTrackRegistry();
  @override
  Future<void> prepare(bool Function() active) =>
      prepareAndroidScreenShare(active);
  @override
  Future<LocalVideoTrack> capture(ScreenShareCaptureOptions options) async {
    if (!options.captureScreenAudio) {
      return LocalVideoTrack.createScreenShareTrack(options);
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _ensureIOSBroadcastStarted();
    }

    final tracks = await LocalVideoTrack.createScreenShareTracksWithAudio(
      nativeScreenCaptureOptions(options, defaultTargetPlatform),
    );
    final videos = tracks.whereType<LocalVideoTrack>().toList();
    if (videos.isEmpty) {
      for (final track in tracks) {
        await track.stop();
      }
      throw StateError('Система не создала видеодорожку демонстрации.');
    }
    final video = videos.first;
    final audios = tracks.whereType<LocalAudioTrack>().toList();
    final audio = audios.isEmpty ? null : audios.first;
    if (audio == null) {
      for (final track in tracks) {
        await track.stop();
      }
      throw StateError(
        'Операционная система не создала дорожку системного звука. '
        'Проверьте версию ОС, разрешения и источник звука.',
      );
    }
    _screenAudioTracks.register(video, audio);
    return video;
  }

  Future<void> _ensureIOSBroadcastStarted() async {
    final broadcast = BroadcastManager();
    if (broadcast.isBroadcasting) return;

    final started = Completer<void>();
    void onChanged() {
      if (broadcast.isBroadcasting && !started.isCompleted) started.complete();
    }

    broadcast.addListener(onChanged);
    try {
      await broadcast.requestActivation();
      onChanged();
      await started.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw StateError(
          'Системная трансляция не запущена. Разрешите ReplayKit и повторите попытку.',
        ),
      );
    } finally {
      broadcast.removeListener(onChanged);
    }
  }

  @override
  Future<void> publish(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
  ) async {
    final participant = room.localParticipant;
    if (participant == null) throw StateError('Голосовое подключение закрыто.');
    await participant.publishVideoTrack(
      track,
      publishOptions: nativeScreenPublishPlan(
        quality,
        rollout,
        defaultTargetPlatform,
        sourceDimensions: defaultTargetPlatform == TargetPlatform.android
            ? null
            : screenShareCaptureDimensions(track) ??
                  (defaultTargetPlatform == TargetPlatform.windows
                      ? dimensions
                      : null),
      ),
    );
    final audio = _screenAudioTracks[track];
    if (audio != null) {
      await participant.publishAudioTrack(audio);
    }
  }

  @override
  Future<bool> updateQuality(
    Room room,
    LocalVideoTrack track,
    ScreenShareQuality quality,
    VideoDimensions? dimensions,
    bool Function() isCurrent,
  ) => updateScreenShareProfile(room, track, quality, dimensions, isCurrent);

  @override
  Future<void> discard(Room room, LocalVideoTrack track) async {
    final audio = _screenAudioTracks.take(track);
    try {
      final participant = room.localParticipant;
      if (audio != null) {
        final audioPublications =
            participant?.audioTrackPublications.toList() ?? [];
        for (final publication in audioPublications) {
          if (identical(publication.track, audio)) {
            await participant!.removePublishedTrack(
              publication.sid,
              stopOnUnpublish: false,
            );
          }
        }
      }
      final publications = participant?.videoTrackPublications.toList() ?? [];
      for (final publication in publications) {
        if (identical(publication.track, track)) {
          await participant!.removePublishedTrack(publication.sid);
        }
      }
    } finally {
      try {
        if (audio != null) await _screenAudioTracks.stop(audio);
      } finally {
        await track.stop();
      }
    }
  }

  @override
  Future<void> stop(Room room) async {
    final participant = room.localParticipant;
    try {
      if (participant != null) {
        final audioPublications = participant.audioTrackPublications.toList();
        for (final publication in audioPublications) {
          if (publication.source == TrackSource.screenShareAudio) {
            await participant.removePublishedTrack(
              publication.sid,
              stopOnUnpublish: false,
            );
          }
        }
        await participant.setScreenShareEnabled(false);
      }
    } finally {
      await _screenAudioTracks.stopAll();
    }
  }

  @override
  Future<void> disableBackground() => disableAndroidScreenShareBackground();
}
