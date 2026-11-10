part of '../../app_state_test.dart';

void _registerVoiceAdmission() {
  test('requests an existing voice lease transfer immediately', () async {
    final api = _FakeApi(
      topology,
      voiceFailure: const ApiFailure(
        'Голос уже подключён в другом окне',
        status: 409,
        code: 'ACTIVE_VOICE_LEASE',
      ),
      transferFailure: const ApiFailure('Перенос недоступен', status: 503),
    );
    final state = AppState(api);
    addTearDown(state.dispose);
    const voiceChannel = GuildChannel(
      id: 'voice-1',
      name: 'Лобби',
      kind: ChannelKind.voice,
      admissionClosed: false,
    );

    await state.joinVoice(voiceChannel);

    expect(state.voicePhase, VoicePhase.error);
    expect(api.voiceTransferAttempts, [true]);
    expect(state.error, contains('Перенос недоступен'));
  });

  test('reports an unrelated voice admission failure without retry', () async {
    final api = _FakeApi(
      topology,
      transferFailure: const ApiFailure('Вход закрыт', status: 403),
    );
    final state = AppState(api);
    addTearDown(state.dispose);
    const voiceChannel = GuildChannel(
      id: 'voice-1',
      name: 'Лобби',
      kind: ChannelKind.voice,
      admissionClosed: false,
    );

    await state.joinVoice(voiceChannel);

    expect(api.voiceTransferAttempts, [true]);
    expect(state.error, 'Вход закрыт');
  });
}
