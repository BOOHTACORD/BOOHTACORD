part of '../../app_state_test.dart';

void _registerAudioRecovery() {
  test(
    'does not show a stale scan error after a newer hotplug event',
    () async {
      final changes = StreamController<List<MediaDevice>>.broadcast();
      final oldScan = Completer<List<MediaDevice>>();
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () => oldScan.future,
        audioDeviceChanges: changes.stream,
      );
      addTearDown(() async {
        state.dispose();
        await changes.close();
      });
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);
      changes.add(const [
        MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      oldScan.completeError(StateError('obsolete scan failed'));
      await Future<void>.delayed(Duration.zero);

      expect(state.audioInputDevices.single.deviceId, 'usb-mic');
      expect(state.audioSettingsError, isNull);
      expect(state.audioDeviceScanFailed, isFalse);
      expect(state.audioDevicesLoading, isFalse);
    },
  );

  test(
    'marks a current audio device scan failure separately from empty',
    () async {
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => throw StateError('enumeration failed'),
      );
      addTearDown(state.dispose);
      await state.initialize();

      await state.refreshAudioDevices();

      expect(state.audioDeviceScanFailed, isTrue);
      expect(state.audioDeviceScanStatus, AudioDeviceScanStatus.error);
      expect(state.audioSettingsError, contains('Не удалось получить список'));
      expect(state.audioInputDevices, isEmpty);
      expect(state.audioOutputDevices, isEmpty);
    },
  );

  test('queues a device refresh requested during an active scan', () async {
    final firstScan = Completer<List<MediaDevice>>();
    final secondScan = Completer<List<MediaDevice>>();
    var scanCount = 0;
    final state = AppState(
      _FakeApi(topology),
      audioDeviceLoader: () {
        scanCount++;
        return scanCount == 1 ? firstScan.future : secondScan.future;
      },
    );
    addTearDown(state.dispose);
    await state.initialize();

    final initialRefresh = state.refreshAudioDevices();
    await Future<void>.delayed(Duration.zero);
    final queuedRefresh = state.refreshAudioDevices();
    firstScan.complete(const [
      MediaDevice('default-input', 'System default', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(scanCount, 2);
    secondScan.complete(const [
      MediaDevice('usb-input', 'USB microphone', 'audioinput', null),
      MediaDevice('usb-output', 'USB headphones', 'audiooutput', null),
    ]);
    await Future.wait([initialRefresh, queuedRefresh]);

    expect(state.audioInputDevices.single.deviceId, 'usb-input');
    expect(state.audioOutputDevices.single.deviceId, 'usb-output');
    expect(state.audioDevicesLoading, isFalse);
  });
}
