part of '../audio_device_check.dart';

extension _NativeSpeakerCheck on NativeAudioDeviceCheckService {
  Future<void> _playSpeaker({String? deviceId, String? deviceLabel}) async {
    final soloud = SoLoud.instance;
    if (soloud.isInitialized) {
      throw const AudioDeviceCheckFailure(
        'Сейчас занят звуковой тест. Повторите попытку через мгновение.',
      );
    }
    if (AndroidAudioDevices.isAndroid &&
        AndroidAudioDevices.isNativeOutputRoute(deviceId)) {
      final selected = await AndroidAudioDevices.selectNativeOutput(deviceId!);
      if (!selected) {
        throw const AudioDeviceCheckFailure(
          'Не удалось выбрать аудиовыход для проверки. Проверьте его подключение и повторите попытку.',
        );
      }
    }

    final outputDevice = resolvePlaybackDevice(
      selectedId: deviceId,
      selectedLabel: deviceLabel,
      available: soloud.listPlaybackDevices(),
    );
    AudioSource? source;
    SoundHandle? handle;
    var initializedHere = false;
    final release = SoundEngineLease.acquire();
    if (release == null)
      throw const AudioDeviceCheckFailure(
        'Сейчас занят звуковой выход. Повторите проверку через мгновение.',
      );
    try {
      await soloud.init(device: outputDevice);
      initializedHere = true;
      source = await soloud.loadWaveform(WaveForm.sin, false, 1, 0);
      soloud.setWaveformFreq(source, 440);
      handle = soloud.play(source, volume: 0.12);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } catch (_) {
      throw const AudioDeviceCheckFailure(
        'Не удалось воспроизвести сигнал. Проверьте выбранный динамик и его подключение.',
      );
    } finally {
      if (handle != null && initializedHere && soloud.isInitialized) {
        try {
          await soloud.stop(handle);
        } catch (_) {}
      }
      if (source != null && initializedHere && soloud.isInitialized) {
        try {
          await soloud.disposeSource(source);
        } catch (_) {}
      }
      if (initializedHere && soloud.isInitialized) {
        try {
          await soloud.deinitAsync();
        } catch (_) {}
      }
      release();
    }
  }
}
