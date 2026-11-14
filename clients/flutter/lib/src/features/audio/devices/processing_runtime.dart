part of 'processing.dart';

extension AudioProcessingRuntime on AudioDeviceState {
  Future<void> _applyTrackProcessing(
    LocalAudioTrack track,
    AudioProcessingPreferences next,
  ) => applyVoiceProcessingForPlatform(
    platform: defaultTargetPlatform,
    current: track.currentOptions,
    next: next,
    recapture: (options) async {
      await track.restartTrack(options);
      if (microphoneMutedIntent || track.muted) await track.disable();
    },
    // ignore: experimental_member_use
    updateRuntime: track.setAudioProcessingOptions,
  );
  void _monitorNativeNoise() {
    nativeNoise.monitor((reason) async {
      final targetRoom = room;
      final track = targetRoom?.localParticipant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is! LocalAudioTrack || isDisposed) return;
      final recovery = ++nativeRecoveryRevision;
      final tryBackup =
          audioProcessing.noiseSuppressionMode == NoiseSuppressionMode.auto &&
          captureNoiseOverride == NoiseSuppressionMode.deepfilter;
      bool current() =>
          recovery == nativeRecoveryRevision &&
          identical(targetRoom, room) &&
          !isDisposed;
      Future<void> restoreProcessing() async {
        await track.mute(stopOnMute: false);
        if (!current()) return;
        await nativeNoise.reset();
        if (!current()) return;
        final mode = tryBackup
            ? await nativeNoise.prepareAutoBackup()
            : NoiseSuppressionMode.browser;
        if (!current()) return;
        if (mode == NoiseSuppressionMode.browser) {
          await nativeNoise.useFallback(reason, captureApplied: false);
        }
        if (!current()) return;
        await _applyTrackProcessing(
          track,
          audioProcessing.copyWith(noiseSuppressionMode: mode),
        );
        if (!current()) return;
        captureNoiseOverride = mode;
        if (mode == NoiseSuppressionMode.browser) {
          nativeNoise.confirmFallback(reason);
        }
        if (!microphoneMutedIntent) await track.unmute(stopOnMute: false);
      }

      try {
        await restoreProcessing().timeout(
          Duration(milliseconds: tryBackup ? 3000 : 850),
        );
      } catch (_) {
        nativeRecoveryRevision++;
        microphoneMutedIntent = true;
        unawaited(track.mute(stopOnMute: false).catchError((_) => false));
        nativeNoise.failMuted(
          tryBackup ? 'auto-recovery-failed' : 'browser-recovery-failed',
        );
        audioSettingsError =
            'Не удалось восстановить микрофон. Отправка звука выключена.';
      }
      notifyListeners();
    });
  }
}
