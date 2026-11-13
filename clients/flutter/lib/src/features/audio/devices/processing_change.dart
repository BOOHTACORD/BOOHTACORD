part of 'processing.dart';

extension AudioProcessingChange on AudioDeviceState {
  Future<void> _setAudioProcessing(AudioProcessingPreferences next) async {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    bool current() =>
        !isDisposed &&
        ticket.isActive &&
        identical(settings, preferences) &&
        identical(targetRoom, room);
    if (!current()) return;
    final previous = audioProcessing;
    final previousOverride = captureNoiseOverride;
    audioSettingsError = null;
    final track = targetRoom?.localParticipant
        ?.getTrackPublicationBySource(TrackSource.microphone)
        ?.track;
    try {
      if (targetRoom == null) {
        await settings?.setProcessing(next);
        if (current()) audioProcessing = next;
        if (current()) notifyListeners();
        return;
      }
      if (track is LocalAudioTrack) await track.mute(stopOnMute: false);
      await nativeNoise.reset();
      var mode = await nativeNoise.prepare(next.noiseSuppressionMode);
      if (!current()) return;
      if (mode != next.noiseSuppressionMode) {
        await nativeNoise.useFallback(
          nativeNoise.state.failureReason ?? 'unsupported',
          captureApplied: false,
        );
        if (!current()) return;
      }
      final effective = next.copyWith(noiseSuppressionMode: mode);
      if (track is LocalAudioTrack) {
        await _applyTrackProcessing(track, effective);
        var fellBack = false;
        if (!await prepareNoiseModelForCaptureIfNeeded(
          current,
          mode: mode,
          onFallback: () => fellBack = true,
        )) {
          return;
        }
        if (fellBack) {
          mode = NoiseSuppressionMode.browser;
          await _applyTrackProcessing(
            track,
            next.copyWith(noiseSuppressionMode: mode),
          );
        }
      }
      if (!current()) return;
      if (mode != next.noiseSuppressionMode) {
        await nativeNoise.useFallback(
          nativeNoise.state.failureReason ?? 'unsupported',
          unsupported:
              next.noiseSuppressionMode == NoiseSuppressionMode.rnnoise ||
              nativeNoise.state.failureReason == 'processor-unavailable' ||
              nativeNoise.state.failureReason == 'unsupported',
          captureApplied: track is LocalAudioTrack,
        );
      }
      await applyMicrophoneControls(agc: next.autoGainControl);
      audioProcessing = next;
      captureNoiseOverride = mode;
      await settings?.setProcessing(next);
      if (!current()) return;
      if (track is LocalAudioTrack && !microphoneMutedIntent) {
        await track.unmute(stopOnMute: false);
      }
      if (track is LocalAudioTrack) _monitorNativeNoise();
    } catch (cause) {
      if (!current()) return;
      audioProcessing = previous;
      captureNoiseOverride = previousOverride;
      try {
        await _restoreNoiseProcessing(
          track,
          previous,
          previousOverride,
          current,
        );
        if (!current()) return;
      } catch (_) {
        microphoneMutedIntent = true;
        if (track is LocalAudioTrack) await track.mute(stopOnMute: false);
        nativeNoise.failMuted('rollback-failed');
      }
      audioSettingsError =
          'Не удалось применить обработку микрофона: ${cause.runtimeType}.';
    }
    if (current()) notifyListeners();
  }
}
