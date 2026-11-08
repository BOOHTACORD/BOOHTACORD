import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets(
      'generation, confirmation, editing and cleanup at ${size.width}',
      (tester) async {
        await mountRegistration(tester, size);
        await press(tester, generateButton);
        var field = passwordInput(tester);
        expect(field.controller.text.length, 24);
        expect(field.obscureText, isFalse);
        expect(field.focusNode.hasFocus, isTrue);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
        expect(field.enableIMEPersonalizedLearning, isFalse);
        expect(field.autofillHints, contains(AutofillHints.newPassword));
        expect(find.text('Надёжный пароль сгенерирован'), findsOneWidget);
        await press(tester, find.byTooltip('Скрыть пароль'));
        expect(passwordInput(tester).obscureText, isTrue);
        await tester.enterText(passwordField, 'manual-password-123');
        await press(tester, generateButton);
        expect(
          find.text('Заменить введённый пароль сгенерированным?'),
          findsOneWidget,
        );
        expect(
          passwordInput(tester).controller.text == 'manual-password-123',
          isTrue,
        );
        await press(tester, find.text('Оставить'));
        expect(
          passwordInput(tester).controller.text == 'manual-password-123',
          isTrue,
        );
        await press(tester, generateButton);
        await press(tester, find.text('Заменить'));
        expect(passwordInput(tester).controller.text.length, 24);
        expect(passwordInput(tester).obscureText, isFalse);
        await press(tester, find.text('Войти').first);
        expect(passwordInput(tester).controller.text.isEmpty, isTrue);
        expect(passwordInput(tester).obscureText, isTrue);
        expect(generateButton, findsNothing);
        expect(find.text('Надёжный пароль сгенерирован'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('generation clears previous form validation and server error', (
    tester,
  ) async {
    final state = await mountRegistration(tester, const Size(1440, 900));
    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'new_member',
    );
    await tester.enterText(passwordField, 'short');
    await press(tester, find.widgetWithText(FilledButton, 'Создать аккаунт'));
    expect(
      find.text('Пароль должен содержать от 12 до 128 символов.'),
      findsOneWidget,
    );
    state.reportError('Предыдущая ошибка');
    await tester.pump();
    await press(tester, generateButton);
    await press(tester, find.text('Заменить'));
    expect(
      find.text('Пароль должен содержать от 12 до 128 символов.'),
      findsNothing,
    );
    expect(state.error, isNull);
    expect(passwordInput(tester).focusNode.hasFocus, isTrue);
  });
}
