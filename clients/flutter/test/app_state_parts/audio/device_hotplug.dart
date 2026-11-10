part of '../../app_state_test.dart';

void _registerAudioHotplug() {
  test('updates audio devices when a headset is connected', () async {
    final changes = StreamController<List<MediaDevice>>.broadcast();
    final state = AppState(
      _FakeApi(topology),
      audioDeviceLoader: () async => const [
        MediaDevice('built-in', 'Built-in microphone', 'audioinput', null),
      ],
      audioDeviceChanges: changes.stream,
    );
    addTearDown(() async {
      state.dispose();
      await changes.close();
    });
    await state.initialize();
    await state.refreshAudioDevices();
    state.selectedAudioInputId = 'built-in';
    state.toggleWorkspacePanel(WorkspacePanel.audio);

    changes.add(const [
      MediaDevice('usb-mic', 'USB microphone', 'audioinput', null),
      MediaDevice('usb-speaker', 'USB speaker', 'audiooutput', null),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(state.audioInputDevices.single.deviceId, 'usb-mic');
    expect(state.audioOutputDevices.single.deviceId, 'usb-speaker');
    expect(state.selectedAudioInputId, 'usb-mic');
    expect(
      state.audioDeviceWarning,
      'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.',
    );
  });

  test(
    'warns and selects an available device when the chosen mic is disconnected',
    () async {
      SharedPreferences.setMockInitialValues({});
      var available = const [
        MediaDevice('mic-old', 'USB microphone', 'audioinput', null),
        MediaDevice('speaker', 'Speakers', 'audiooutput', null),
      ];
      final state = AppState(
        _FakeApi(topology),
        audioDeviceLoader: () async => available,
      );
      addTearDown(state.dispose);
      await state.initialize();
      await state.refreshAudioDevices();
      state.selectedAudioInputId = 'mic-old';
      state.selectedAudioOutputId = 'speaker';

      available = const [];
      await state.refreshAudioDevices();

      expect(state.selectedAudioInputId, 'mic-old');
      expect(state.selectedAudioOutputId, 'speaker');
      expect(state.audioDeviceWarning, isNull);

      available = const [
        MediaDevice('mic-new', 'Built-in microphone', 'audioinput', null),
        MediaDevice('speaker', 'Speakers', 'audiooutput', null),
      ];
      await state.refreshAudioDevices();

      expect(state.selectedAudioInputId, 'mic-new');
      expect(state.selectedAudioOutputId, 'speaker');
      expect(
        state.audioDeviceWarning,
        'Выбранный микрофон отключён. Выберите доступное устройство и проверьте звук.',
      );
    },
  );
}
