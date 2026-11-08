import 'dart:io';

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> shortPasswordAndLogin(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  AppState state,
  String password,
) async {
  await tester.tap(find.text('Регистрация'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('auth-login-field')),
    'qa_short',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password-field')),
    'abcdefghijk',
  );
  await tester.ensureVisible(
    find.widgetWithText(FilledButton, 'Создать аккаунт'),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
  await tester.pumpAndSettle();
  expect(
    find.text('Пароль должен содержать от 12 до 128 символов.'),
    findsOneWidget,
  );
  if (Platform.isAndroid) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
  }
  await binding.takeScreenshot('three-bugs-android-password');
  await tester.tap(find.text('Войти').first);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('auth-login-field')),
    'qa_admin',
  );
  await tester.enterText(
    find.byKey(const ValueKey('auth-password-field')),
    password,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Войти'));
  await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
  for (
    var i = 0;
    i < 160 && (state.phase != AppPhase.ready || !state.realtimeConnected);
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(state.phase, AppPhase.ready);
  expect(state.realtimeConnected, isTrue);
}
