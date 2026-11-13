import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'bootstrap.dart';
import 'input_selection/capture.dart';
import 'input_selection/desktop_switch.dart';
import 'input_selection/selection.dart';
import 'input_selection/switch.dart';
import 'inventory.dart';
import 'microphone.dart';
import 'native_inventory_readiness.dart';
import 'output_selection/selection.dart';
import 'prejoin_selection/restore.dart';
import 'processing.dart';
import 'scan.dart';
import 'state.dart';

class AudioDeviceController extends AudioDeviceState
    with
        AudioDeviceScan,
        AudioDeviceInventory,
        AudioInputTrackCapture,
        AudioInputDesktopSwitch,
        AudioInputSwitch,
        AudioInputSelection,
        AudioOutputSelection,
        AudioDevicePreJoinRestore,
        AudioDeviceProcessing,
        AudioDeviceMicrophone,
        AudioDeviceNativeInventoryReadiness,
        AudioDeviceBootstrap {
  AudioDeviceController({
    required super.readRoom,
    super.readAccountId,
    super.loader,
    super.changes,
    super.nativeBootstrap,
    super.scope,
  }) {
    nativeNoise.addListener(notifyListeners);
    // Meter widgets subscribe directly; avoid rebuilding the workspace at 10 Hz.
  }

  @override
  void watch() {
    if (isDisposed) return;
    subscription ??= (changes ?? Hardware.instance.onDeviceChange.stream)
        .listen((devices) {
          if (isDisposed || !scope.capture().isActive) return;
          if (nativeAudioBootstrapPending) return;
          final revision = ++deviceRevision;
          acceptAudioDeviceChange(devices);
          applyAudioDevices(devices);
          notifyListeners();
          if (!audioDeviceScanFailed) {
            unawaited(applyAndroidAdditions(devices, revision));
          }
        });
  }
}
