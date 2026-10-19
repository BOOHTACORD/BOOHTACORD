import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/screens/password_reset_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets('password reset fields reveal and hide independently', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    state.openPasswordResetLink(
      'https://v.bootybay.ru/reset-password#token=${List.filled(43, 'a').join()}',
    );
    addTearDown(state.dispose);

    await loadUiuxVisualCaptureFonts();
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: RepaintBoundary(
          key: captureKey,
          child: PasswordResetScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await captureUiuxBoundary(
      tester,
      find.byKey(captureKey),
      fileName: 'password-reset-visibility-mobile.png',
      pixelRatio: 1,
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(tester.widget<TextField>(fields.at(0)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);

    final firstToggle = find.descendant(
      of: fields.at(0),
      matching: find.byType(IconButton),
    );
    final secondToggle = find.descendant(
      of: fields.at(1),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(firstToggle).tooltip, 'Показать пароль');
    expect(tester.widget<IconButton>(secondToggle).tooltip, 'Показать пароль');

    await tester.tap(firstToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(0)).obscureText, isFalse);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    expect(tester.widget<IconButton>(firstToggle).tooltip, 'Скрыть пароль');

    await tester.tap(secondToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isFalse);

    await tester.tap(firstToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(0)).obscureText, isTrue);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isFalse);
    expect(tester.takeException(), isNull);
  });
}
