import 'package:livekit_client/livekit_client.dart';

/// Owns the audio tracks created alongside local screen-share video tracks.
class ScreenAudioTrackRegistry {
  final Map<LocalVideoTrack, LocalAudioTrack> _tracks = {};

  LocalAudioTrack? operator [](LocalVideoTrack videoTrack) =>
      _tracks[videoTrack];

  void register(LocalVideoTrack videoTrack, LocalAudioTrack audioTrack) {
    _tracks[videoTrack] = audioTrack;
  }

  LocalAudioTrack? take(LocalVideoTrack videoTrack) =>
      _tracks.remove(videoTrack);

  Future<void> stop(LocalAudioTrack track) => _stopTracks([track]);

  Future<void> stopAll() async {
    final tracks = _tracks.values.toSet().toList();
    _tracks.clear();
    await _stopTracks(tracks);
  }

  Future<void> _stopTracks(List<LocalAudioTrack> tracks) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final track in tracks) {
      try {
        await track.stop();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
