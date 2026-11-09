part of '../../app_state_test.dart';

void _registerProfileValidation() {
  test('keeps profile load errors separate and clears them on retry', () async {
    final api = _FakeApi(topology)
      ..profileFailure = const ApiFailure('Профиль временно недоступен.');
    final state = AppState(api);
    addTearDown(state.dispose);

    await state.refreshProfile();

    expect(state.profile, isNull);
    expect(state.profileLoading, isFalse);
    expect(state.profileLoadError, 'Профиль временно недоступен.');
    expect(state.error, isNull);

    api.profileFailure = null;
    await state.refreshProfile();

    expect(state.profileLoadError, isNull);
    expect(state.profile?.displayName, 'Участник');
    expect(state.profileLoading, isFalse);
  });

  test(
    'profile display name validation matches web code points exactly',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);

      const displayName = '  😀  ';
      expect(await state.saveDisplayName(displayName), isTrue);
      expect(api.updatedDisplayName, displayName);

      final tooLong = List.filled(65, '😀').join();
      expect(await state.saveDisplayName(tooLong), isFalse);
      expect(api.updatedDisplayName, displayName);
      expect(state.error, 'Имя должно содержать от 1 до 64 символов.');
    },
  );

  test(
    'profile password validation matches web 12–128 code point limits',
    () async {
      final api = _FakeApi(topology);
      final state = AppState(api);
      addTearDown(state.dispose);
      final valid = List.filled(12, '😀').join();
      final tooLong = List.filled(129, '😀').join();

      expect(await state.updatePassword(tooLong, valid), isFalse);
      expect(await state.updatePassword(valid, tooLong), isFalse);
      expect(api.passwordChangeRequests, 0);

      expect(await state.updatePassword(valid, valid), isTrue);
      expect(api.passwordChangeRequests, 1);
    },
  );
}
