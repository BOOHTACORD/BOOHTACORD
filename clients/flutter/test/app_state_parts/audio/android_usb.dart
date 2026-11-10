part of '../../app_state_test.dart';

void _registerAudioAndroidUsb() {
  test(
    'retains Android USB routes after a WebRTC device-change event',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const audioChannel = MethodChannel('boohtacord/audio_devices');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
            if (call.method == 'enumerateAudioDevices') {
              return [
                {
                  'deviceId': '41',
                  'kind': 'audioinput',
                  'label': 'USB microphone',
                  'groupId': 'usb:41',
                },
                {
                  'deviceId': 'android-usb-route:42',
                  'kind': 'audiooutput',
                  'label': 'USB headset',
                  'groupId': 'usb:42',
                },
              ];
            }
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
        MediaDevice('default-mic', 'Microphone', 'audioinput', null),
        MediaDevice('default-speaker', 'Speaker', 'audiooutput', null),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        state.audioInputDevices.map((device) => device.deviceId),
        contains('41'),
      );
      expect(
        state.audioOutputDevices.map((device) => device.deviceId),
        contains('android-usb-route:42'),
      );
    },
  );
}
