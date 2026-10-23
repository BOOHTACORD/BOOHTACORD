import 'dart:convert';
import 'dart:ui' show SemanticsRole, Tristate;

import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/app_version.dart';
import 'package:boohtacord_desktop/src/screens/auth_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  setUpAll(loadUiuxVisualCaptureFonts);
  testWidgets(
    'busy login preserves masked editable form with a manual retry delay',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      FlutterSecureStorage.setMockInitialValues({});
      var calls = 0;
      final state = AppState(
        ApiClient(
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'error': {'code': 'AUTH_BUSY'},
              }),
              503,
              headers: {'content-type': 'application/json', 'retry-after': '7'},
            );
          }),
        ),
      )..phase = AppPhase.signedOut;
      addTearDown(state.dispose);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: RepaintBoundary(
            key: captureKey,
            child: AuthScreen(state: state),
          ),
        ),
      );
      final login = find.byKey(const ValueKey('auth-login-field'));
      final password = find.byKey(const ValueKey('auth-password-field'));
      await tester.enterText(login, 'synthetic-user');
      await tester.enterText(password, 'synthetic password');
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(
        find.descendant(of: password, matching: find.byType(EditableText)),
      );
      expect(input.controller.text, 'synthetic password');
      expect(input.obscureText, isTrue);
      expect(input.readOnly, isFalse);
      expect(find.textContaining('вручную через 7 с.'), findsOneWidget);
      expect(calls, 1);
      expect(state.phase, AppPhase.signedOut);
      await captureUiuxBoundary(
        tester,
        find.byKey(captureKey),
        fileName: 'auth-capacity-mobile.png',
        pixelRatio: 1,
      );
    },
  );
  testWidgets('auth card follows web width on Android portrait viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(tester.getSize(find.byKey(const ValueKey('auth-card'))).width, 342);
    expect(find.text('BOOHTACORD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the app version before login', (tester) async {
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(find.text(appVersionLabel), findsOneWidget);
  });

  testWidgets('password reset link dialog stays modal until Escape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    final opener = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Есть ссылка для сброса пароля?'),
        matching: find.byType(TextButton),
      ),
    );
    opener.focusNode!.requestFocus();
    await tester.pump();
    expect(opener.focusNode!.hasFocus, isTrue);

    await tester.tap(find.text('Есть ссылка для сброса пароля?'));
    await tester.pumpAndSettle();

    final title = find.text('Ссылка для сброса пароля');
    final route = ModalRoute.of(tester.element(title))!;
    expect(route.barrierDismissible, isFalse);
    expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(opener.focusNode!.hasFocus, isTrue);
  });

  testWidgets('server address dialog stays modal until Escape', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    final opener = tester.widget<TextButton>(
      find.ancestor(
        of: find.textContaining('https://'),
        matching: find.byType(TextButton),
      ),
    );
    opener.focusNode!.requestFocus();
    await tester.pump();
    expect(opener.focusNode!.hasFocus, isTrue);

    await tester.tap(find.textContaining('https://'));
    await tester.pumpAndSettle();

    final title = find.text('Сервер гильдии');
    final route = ModalRoute.of(tester.element(title))!;
    expect(route.barrierDismissible, isFalse);
    expect(route.traversalEdgeBehavior, TraversalEdgeBehavior.closedLoop);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(title, findsNothing);
    expect(opener.focusNode!.hasFocus, isTrue);
  });

  testWidgets('login and password fields keep a usable mobile height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(
      tester.getSize(find.byKey(const ValueKey('auth-login-field'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-password-field'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('auth card uses web maximum width on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(tester.getSize(find.byKey(const ValueKey('auth-card'))).width, 440);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth mode tabs match web sizing and tab semantics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    expect(
      tester.getSize(find.byKey(const ValueKey('auth-mode-switcher'))).height,
      48,
    );
    final tabList = tester.getSemantics(
      find.byKey(const ValueKey('auth-mode-tablist-semantics')),
    );
    expect(tabList.getSemanticsData().role, SemanticsRole.tabBar);

    final loginTab = tester.getSemantics(
      find.byKey(const ValueKey('auth-mode-tab-Войти')),
    );
    expect(loginTab.getSemanticsData().role, SemanticsRole.tab);
    expect(
      loginTab.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('auth-mode-tab-Регистрация')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('auth mode tabs are reachable and activatable by keyboard', (
    tester,
  ) async {
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('auth-mode-tab-Регистрация')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('login keeps focus and entered text through app-state rebuilds', (
    tester,
  ) async {
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: state,
          builder: (context, _) => AuthScreen(state: state),
        ),
      ),
    );

    final login = find.byKey(const ValueKey('auth-login-field'));
    await tester.tap(login);
    await tester.enterText(login, 'p');
    expect(tester.testTextInput.isVisible, isTrue);

    state.notifyListeners();
    await tester.pump();

    // Keep using the same simulated IME connection after the rebuild, as a
    // mobile keyboard does when it sends the next composing/editing update.
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'pi'));
    state.notifyListeners();
    await tester.pump();

    final field = tester.widget<EditableText>(
      find.descendant(of: login, matching: find.byType(EditableText)),
    );
    expect(field.controller.text, 'pi');
    expect(field.focusNode.hasFocus, isTrue);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('login submits a shorter existing password', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <http.Request>[];
    final state = AppState(
      ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHENTICATED',
                'message': 'Неверный логин или пароль',
              },
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    )..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'existing_user',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'shortpass',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/auth/login');
    expect(
      (jsonDecode(requests.single.body) as Map<String, dynamic>)['password'],
      'shortpass',
    );
  });

  testWidgets(
    'login explains platform errors without exposing plugin details',
    (tester) async {
      final state = AppState(
        _FailingAuthenticationApi(
          PlatformException(
            code: 'secure_storage_read',
            message: 'Keystore operation failed; cookie=session-secret',
            details: 'password=do-not-show-this',
          ),
        ),
      )..phase = AppPhase.signedOut;
      addTearDown(state.dispose);

      await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
      await tester.enterText(
        find.byKey(const ValueKey('auth-login-field')),
        'existing_user',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'shortpass',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await tester.pumpAndSettle();

      expect(
        state.error,
        'Ошибка системного API: secure_storage_read — '
        'Keystore operation failed; cookie=[скрыто]',
      );
      expect(
        find.text(
          'Ошибка системного API: secure_storage_read — '
          'Keystore operation failed; cookie=[скрыто]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('do-not-show-this'), findsNothing);
      expect(find.textContaining('PlatformException'), findsNothing);
    },
  );

  testWidgets('switching auth mode clears the previous error', (tester) async {
    final state = AppState(ApiClient())..phase = AppPhase.signedOut;
    addTearDown(state.dispose);
    state.reportError('Неверный логин или пароль');

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    expect(find.text('Неверный логин или пароль'), findsOneWidget);

    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный логин или пароль'), findsNothing);
  });

  testWidgets('registration enforces server password length limits', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    var requestCount = 0;
    final state = AppState(
      ApiClient(
        client: MockClient((_) async {
          requestCount++;
          return http.Response('', 204);
        }),
      ),
    )..phase = AppPhase.signedOut;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: AuthScreen(state: state)));
    await tester.tap(find.text('Регистрация'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-login-field')),
      'new_member',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'shortpass12',
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Создать аккаунт'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
    await tester.pumpAndSettle();

    expect(requestCount, 0);
    expect(
      find.text('Пароль должен содержать не менее 12 символов'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'x' * 129,
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Создать аккаунт'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
    await tester.pumpAndSettle();
    expect(requestCount, 0);
    expect(
      find.text('Пароль должен содержать не более 128 символов'),
      findsOneWidget,
    );
  });
}

class _FailingAuthenticationApi extends ApiClient {
  _FailingAuthenticationApi(this.failure);

  final Object failure;

  @override
  Future<void> authenticate(
    String login,
    String password, {
    required bool register,
  }) async {
    throw failure;
  }
}
