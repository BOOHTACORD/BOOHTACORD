part of '../audio_device_check.dart';

extension _NativeMicrophoneCheck on NativeAudioDeviceCheckService {
  Future<Stream<double>> _startMicrophone({
    String? deviceId,
    String? deviceLabel,
  }) async {
    if (_disposed) {
      throw const AudioDeviceCheckFailure('Проверка микрофона недоступна.');
    }
    if (_recording) await stopMicrophone();
    if (!await _recorder.hasPermission()) {
      throw const AudioDeviceCheckFailure(
        'Не удалось проверить микрофон. Проверьте разрешение и выбранное устройство.',
      );
    }

    final devices = await _recorder.listInputDevices();
    final recorderDeviceId = await AndroidAudioDevices.recorderInputDeviceId(
      deviceId,
    );
    final selectedDevice = resolveInputDevice(
      selectedId: deviceId,
      selectedLabel: deviceLabel,
      available: devices,
      recorderDeviceId: recorderDeviceId,
    );

    try {
      // This starts an in-memory PCM stream only; amplitude samples remain
      // local and the PCM data itself is deliberately discarded.
      _recording = true;
      final pcm = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 48000,
          numChannels: 1,
          device: selectedDevice,
        ),
      );
      // Drain and discard PCM locally. The native stream must be consumed so
      // audio frames are not queued in the platform channel while measuring.
      _pcmSubscription = pcm.listen((_) {}, onError: (_) {});
      return _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .map((amplitude) => amplitudePercentFromDb(amplitude.current));
    } catch (_) {
      await _stopRecorderQuietly();
      rethrow;
    }
  }

  Future<void> _stopMicrophone() async {
    if (!_recording) return;
    _recording = false;
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _recorder.stop();
  }

  Future<void> _disposeAudioCheck() async {
    if (_disposed) return;
    _disposed = true;
    await _stopRecorderQuietly();
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _recorder.dispose();
  }

  Future<void> _stopRecorderQuietly() async {
    if (!_recording) return;
    _recording = false;
    try {
      await _pcmSubscription?.cancel();
    } catch (_) {}
    _pcmSubscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }
}
