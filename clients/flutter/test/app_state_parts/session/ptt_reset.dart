part of '../../app_state_test.dart';

void _registerSessionPttReset() {
  test(
    'persists PTT mode and refuses to unmute without an active room',
    () async {
      final state = AppState(_FakeApi(topology));
      addTearDown(state.dispose);
      await state.initialize();

      await state.setPushToTalkKey(97, 'A');
      await state.setAudioActivationMode(AudioActivationMode.ptt);
      await state.setPushToTalkPressed(true);

      expect(state.audioActivationMode, AudioActivationMode.ptt);
      expect(state.pushToTalkKeyId, 97);
      expect(state.pushToTalkKeyLabel, 'A');
      expect(state.pushToTalkPressed, isFalse);
      expect(state.microphoneMuted, isFalse);
    },
  );

  test('releases held PTT state when key-up occurs during reconnect', () async {
    final state = AppState(_FakeApi(topology));
    addTearDown(state.dispose);
    await state.initialize();
    state.audioActivationMode = AudioActivationMode.ptt;
    state.voicePhase = VoicePhase.reconnecting;
    state.pushToTalkPressed = true;
    state.microphoneMuted = false;

    await state.setPushToTalkPressed(false);

    expect(state.pushToTalkPressed, isFalse);
    expect(state.microphoneMuted, isTrue);
  });

  test(
    'clears private workspace state when the session is unauthorized',
    () async {
      final state = AppState(_FakeApi(topology));
      addTearDown(state.dispose);
      await state.initialize();

      state.api.onUnauthorized?.call();

      expect(state.phase, AppPhase.signedOut);
      expect(state.user, isNull);
      expect(state.profile, isNull);
      expect(state.topology, isNull);
      expect(state.messages, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(state.error, isNull);
    },
  );

  test(
    'uses reset link once and returns focus to login on completion',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      final token = List.filled(43, 'a').join();

      state.openPasswordResetLink(
        'https://v.bootybay.ru/reset-password#token=$token',
      );
      expect(state.resetRoute, isTrue);
      expect(state.resetToken, token);

      expect(await state.completePasswordReset('a long password 123'), isTrue);
      expect(api.passwordResetCompleted, isTrue);
      expect(state.resetToken, isNull);
      expect(state.resetCompleted, isTrue);

      state.returnToLogin();
      expect(state.resetRoute, isFalse);
      expect(state.focusLoginOnMount, isTrue);
    },
  );
}
