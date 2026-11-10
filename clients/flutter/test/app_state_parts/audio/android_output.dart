part of '../../app_state_test.dart';

void _registerAudioAndroidOutput() {
  test(
    'keeps Android system output available after an empty device-change scan',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const audioChannel = MethodChannel('boohtacord/audio_devices');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
            if (call.method == 'enumerateAudioDevices') return const [];
            return null;
          });
      final changes = StreamController<List<MediaDevice>>.broadcast();
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => const [],
        audioDeviceChanges: changes.stream,
      );
      addTearDown(() async {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(audioChannel, null);
        state.dispose();
        await changes.close();
      });
      await state.initialize();
      state.toggleWorkspacePanel(WorkspacePanel.audio);

      changes.add(const [
        MediaDevice('built-in-mic', 'Built-in microphone', 'audioinput', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        state.audioOutputDevices,
        contains(
          const MediaDevice(
            'default',
            'Системный динамик',
            'audiooutput',
            'android:default',
          ),
        ),
      );
    },
  );

  test('does not replace a hotplug event with a stale device scan', () async {
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
    oldScan.complete(const [
      MediaDevice('built-in', 'Built-in microphone', 'audioinput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(state.audioInputDevices.single.deviceId, 'usb-mic');
    expect(state.audioDevicesLoading, isFalse);
  });
}
