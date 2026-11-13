import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../services/client_telemetry.dart';
import '../state.dart';
import 'capture.dart';
import 'desktop_switch.dart';

mixin AudioInputSwitch
    on AudioDeviceState, AudioInputTrackCapture, AudioInputDesktopSwitch {
  Future<void> switchAudioInput(String deviceId) async {
    final ticket = scope.capture();
    final settings = preferences;
    final targetRoom = room;
    bool current() =>
        !isDisposed &&
        ticket.isActive &&
        identical(settings, preferences) &&
        identical(targetRoom, room);
    if (!current()) return;
    final device = audioInputDevices
        .where(
          (candidate) =>
              candidate.deviceId == deviceId ||
              (deviceId.isEmpty && candidate.deviceId == 'default'),
        )
        .firstOrNull;
    if (device == null) return;

    final previous = selectedAudioInputId;
    var switchOutcome = 'error';
    audioDeviceWarning = null;
    try {
      final track = room?.localParticipant
          ?.getTrackPublicationBySource(TrackSource.microphone)
          ?.track;
      if (track is LocalAudioTrack) {
        if (_usesDesktopAudioDeviceModule) {
          await switchDesktopInput(
            track,
            device,
            current,
            selectDevice: () => targetRoom!.setAudioInputDevice(device),
          );
        } else {
          await switchInputTrack(
            track,
            device,
            current,
            () => switchOutcome = 'fallback',
          );
        }
      } else if (room != null) {
        await room!.setAudioInputDevice(device);
        if (!current()) return;
      } else {
        await Hardware.instance.selectAudioInput(device);
        if (!current()) return;
      }
      if (!current()) return;
      selectedAudioInputId = device.deviceId;
      await settings?.setInputDevice(device.deviceId);
      if (!current()) return;
      audioSettingsError = null;
      ClientTelemetry.audioInputSwitch(
        targetRoom == null ? 'prejoin' : 'active',
        'success',
      );
    } catch (cause) {
      if (!current()) return;
      selectedAudioInputId = previous;
      audioSettingsError = _inputSelectionErrorMessage(cause);
      ClientTelemetry.audioInputSwitch(
        targetRoom == null ? 'prejoin' : 'active',
        switchOutcome,
      );
    }
    if (current()) notifyListeners();
  }

  String _inputSelectionErrorMessage(Object cause) {
    if (cause is PlatformException) {
      switch (cause.code) {
        case 'selectAudioInputFailed':
          return 'Система не смогла переключить микрофон. Проверьте подключение устройства и повторите попытку.';
        case 'audioInputEnumerationFailed':
          return 'Не удалось обновить список аудиоустройств. Повторите попытку.';
      }
    }
    return 'Не удалось переключить микрофон. Повторите попытку.';
  }

  bool get _usesDesktopAudioDeviceModule =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
}
