part of '../../app_state_test.dart';

void _registerVoiceScreen() {
  test('screen sharing requires an active voice connection', () async {
    final state = AppState(_FakeApi(topology));
    addTearDown(state.dispose);

    await state.startScreenShare();

    expect(state.screenSharePhase, ScreenSharePhase.error);
    expect(
      state.screenShareError,
      'Подключитесь к голосовому каналу перед демонстрацией.',
    );
  });

  test('screen-share errors keep the native failure detail', () {
    expect(
      screenShareFailureDetail('permission was denied'),
      'permission was denied',
    );
    expect(
      screenShareFailureDetail(StateError('capture service unavailable')),
      'capture service unavailable',
    );
    expect(
      screenShareFailureDetail(
        PlatformException(
          code: 'Capture Failed',
          message: 'Не удалось запустить захват выбранного источника.',
        ),
      ),
      'Не удалось запустить захват выбранного источника.',
    );
    expect(
      screenShareFailureDetail(Exception('encoder negotiation failed')),
      contains('encoder negotiation failed'),
    );
  });
}
