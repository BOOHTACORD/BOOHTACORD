import 'dart:io';

import 'package:boohtacord_desktop/src/features/audio/devices/controller.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../qa/native_audio_auto/monitor.dart';
import 'livekit_progress.dart';

AudioDeviceController createProbeAudio(Room room) =>
    AudioDeviceController(readRoom: () => room)
      ..audioProcessing = const AudioProcessingPreferences(
        noiseSuppressionMode: NoiseSuppressionMode.auto,
        autoGainControl: false,
      )
      ..microphoneMutedIntent = false;

Future<Map<String, Object?>> checkControls(
  Room sender,
  Room receiver,
  AudioDeviceController audio,
  NoiseSuppressionMode expected,
) async {
  if (Platform.environment['BOOHTA_AUTO_PROBE_CONTROLS'] != '1') {
    return {'status': 'NOT_RUN'};
  }
  final rows = <Map<String, Object?>>[];
  try {
    final participant = sender.localParticipant!;
    LocalAudioTrack track() =>
        participant.getTrackPublicationBySource(TrackSource.microphone)!.track!
            as LocalAudioTrack;
    Future<void> progress(String scenario) async {
      final observed = await monitorAuto(
        seconds: 6,
        read: () => readAutoSample(audio.nativeNoise, receiver, expected.name),
      );
      rows.add({'scenario': scenario, ...observed});
      if (observed['success'] != true)
        throw StateError('controls-media-failed');
    }

    for (final aec in [false, true]) {
      for (final agc in [false, true]) {
        await audio.setAudioProcessing(
          AudioProcessingPreferences(
            noiseSuppressionMode: NoiseSuppressionMode.auto,
            echoCancellation: aec,
            autoGainControl: agc,
          ),
        );
        final options = track().currentOptions;
        if (audio.audioSettingsError != null ||
            options.echoCancellation != aec ||
            options.autoGainControl != agc ||
            options.noiseSuppression ||
            audio.audioProcessing.noiseSuppressionMode !=
                NoiseSuppressionMode.auto ||
            audio.captureNoiseOverride != expected ||
            track().muted) {
          throw StateError('processing-configuration-lost');
        }
        await progress('aec-${aec ? 1 : 0}-agc-${agc ? 1 : 0}');
      }
    }
    audio.microphoneMutedIntent = true;
    await participant.setMicrophoneEnabled(false);
    await audio.setAudioProcessing(
      audio.audioProcessing.copyWith(autoGainControl: false),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (audio.audioSettingsError != null ||
        !audio.microphoneMutedIntent ||
        participant.isMicrophoneEnabled() ||
        track().mediaStreamTrack.enabled) {
      throw StateError('processing-mute-intent-lost');
    }
    rows.add({'scenario': 'muted-processing-change', 'success': true});
    audio.microphoneMutedIntent = false;
    await participant.setMicrophoneEnabled(true);
    await progress('unmute-after-processing-change');
    await audio.refreshAudioDevices();
    final physical = audio.audioInputDevices
        .where(
          (device) =>
              device.deviceId.isNotEmpty &&
              !['default', 'communications'].contains(device.deviceId),
        )
        .toList();
    final ids = physical.map((device) => device.deviceId).toSet();
    if (ids.length < 2) {
      return {'success': false, 'deviceStatus': 'BLOCKED', 'rows': rows};
    }
    final first = physical.first;
    final second = physical.firstWhere(
      (device) => device.deviceId != first.deviceId,
    );
    for (final device in [first, second, first]) {
      await audio.selectAudioInput(device.deviceId);
      if (audio.audioSettingsError != null ||
          audio.selectedAudioInputId != device.deviceId ||
          track().currentOptions.deviceId != device.deviceId ||
          !track().currentOptions.echoCancellation ||
          track().currentOptions.autoGainControl ||
          track().currentOptions.noiseSuppression ||
          audio.microphoneMutedIntent ||
          track().muted) {
        throw StateError('input-switch-configuration-lost');
      }
      await progress('device-switch-${rows.length}');
    }
    return {'success': true, 'rows': rows, 'deviceCount': ids.length};
  } catch (error) {
    return {
      'success': false,
      'rows': rows,
      'errorType': error.runtimeType.toString(),
    };
  }
}
