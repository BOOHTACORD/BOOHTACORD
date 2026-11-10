part of '../../app_state_test.dart';

void _registerSessionRestore() {
  test('restores a session and selects the first text channel', () async {
    final api = _FakeApi(topology);
    final state = AppState(api);
    addTearDown(state.dispose);

    await state.initialize();

    expect(state.phase, AppPhase.ready);
    expect(state.user?.accountId, 'account-1');
    expect(state.selectedChannel?.id, textChannel.id);
    expect(state.messages, hasLength(1));
  });

  test(
    'restores saved microphone sensitivity with the signed-in account',
    () async {
      SharedPreferences.setMockInitialValues({
        'audio-preferences:v1:account-1': jsonEncode({'vadThresholdDb': -37}),
      });
      final state = AppState(_FakeApi(topology));
      addTearDown(state.dispose);

      await state.initialize();

      expect(state.phase, AppPhase.ready);
      expect(state.user?.accountId, 'account-1');
      expect(state.microphoneSettings.vadThresholdDb, -37);
      expect(state.audioSettingsError, isNull);
    },
  );

  testWidgets('a temporary TLS failure offers retry without showing login', (
    tester,
  ) async {
    final api = _FakeApi(topology)
      ..sessionFailure = const HandshakeException('temporary TLS failure');
    final state = AppState(api);

    await state.initialize();
    expect(state.phase, AppPhase.connectionError);
    await tester.pumpWidget(BoohtacordApp(state: state));
    expect(find.text('Повторить подключение'), findsOneWidget);
    expect(find.text('Войти'), findsNothing);

    api.sessionFailure = null;
    await tester.tap(find.text('Повторить подключение'));
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.ready);
    expect(state.user?.accountId, 'account-1');
    state.dispose();
  });

  testWidgets(
    'a stalled session check exits loading and offers a retryable error',
    (tester) async {
      final api = _FakeApi(topology)..sessionGate = Completer<SessionUser?>();
      final state = AppState(
        api,
        startupSessionTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(state.dispose);

      await tester.runAsync(state.initialize);

      expect(state.phase, AppPhase.connectionError);
      expect(state.error, contains('Подключение не завершилось вовремя'));
      await tester.pumpWidget(BoohtacordApp(state: state));
      expect(
        find.textContaining('Подключение не завершилось вовремя'),
        findsOneWidget,
      );
      expect(find.text('Повторить подключение'), findsOneWidget);
    },
  );
}
