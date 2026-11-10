part of '../../app_state_test.dart';

void _registerSessionBootstrap() {
  test('a stalled session-storage bootstrap exits loading', () async {
    final api = _FakeApi(topology)..initializationGate = Completer<void>();
    final state = AppState(
      api,
      startupSessionTimeout: const Duration(milliseconds: 20),
    );
    addTearDown(state.dispose);

    final startup = state.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(state.phase, AppPhase.connectionError);
    expect(state.error, contains('Подключение не завершилось вовремя'));
    await startup;
    api.initializationGate!.complete();
  });

  test('a stalled native-notification bootstrap exits loading', () async {
    final driver = NotificationDriverFake()..initializeGate = Completer<void>();
    final state = AppState(
      _FakeApi(topology),
      startupSessionTimeout: const Duration(milliseconds: 20),
      nativeNotifications: NativeNotificationService(
        driver: driver,
        supportedOnCurrentPlatform: true,
      ),
    );
    addTearDown(state.dispose);

    final startup = state.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(state.phase, AppPhase.connectionError);
    expect(state.error, contains('Подключение не завершилось вовремя'));
    await startup;
    driver.initializeGate!.complete();
  });

  test('a stalled account-preparation bootstrap exits loading', () async {
    final preferences = NotificationPreferencesFake()
      ..enabledRead = Completer<bool?>();
    final state = AppState(
      _FakeApi(topology),
      startupSessionTimeout: const Duration(milliseconds: 20),
      nativeNotifications: NativeNotificationService(
        driver: NotificationDriverFake(),
        preferences: preferences,
        supportedOnCurrentPlatform: true,
      ),
    );
    addTearDown(state.dispose);

    final startup = state.initialize();
    await preferences.started.future;
    await Future<void>.delayed(const Duration(milliseconds: 40));

    try {
      expect(state.phase, AppPhase.connectionError);
      expect(state.error, contains('Подключение не завершилось вовремя'));
      await startup;
    } finally {
      preferences.enabledRead!.complete(false);
    }
  });
}
