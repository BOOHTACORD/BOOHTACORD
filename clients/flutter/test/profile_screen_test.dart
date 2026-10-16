import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsRole, Tristate;

import 'package:boohtacord_desktop/src/app_version.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/profile_screen.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/native_notifications.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:boohtacord_desktop/src/widgets/authenticated_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LogoutTrackingState extends AppState {
  _LogoutTrackingState() : super(ApiClient());

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class _ProfileSavingState extends AppState {
  _ProfileSavingState() : super(ApiClient());

  final saveCompleter = Completer<void>();

  @override
  Future<bool> saveDisplayName(String value) async {
    profileSaving = true;
    notifyListeners();
    await saveCompleter.future;
    final current = profile!;
    profile = OwnProfile(
      accountId: current.accountId,
      login: current.login,
      displayName: value,
      role: current.role,
      avatarUrl: current.avatarUrl,
    );
    profileSaving = false;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets('selected settings tab survives rebuilding the profile panel', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Member',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);
    Widget panel() => MaterialApp(
      home: Scaffold(body: ProfileScreen(state: state)),
    );
    await tester.pumpWidget(panel());
    await tester.tap(find.text('О приложении'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Сохранить профиль'), findsNothing);
  });

  testWidgets(
    'profile save state follows unchanged, dirty, pending, and saved',
    (tester) async {
      final state = _ProfileSavingState()
        ..profile = const OwnProfile(
          accountId: 'account-1',
          login: 'member',
          displayName: 'Участник',
          role: 'MEMBER',
        );
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileScreen(state: state)),
        ),
      );

      final save = find.widgetWithText(FilledButton, 'Сохранить профиль');
      final initialStatus = find.text('Изменения не внесены');
      expect(save, findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(
        tester.getSemantics(initialStatus).flagsCollection.isLiveRegion,
        isTrue,
      );

      await tester.enterText(find.byType(TextField).first, 'Новое имя');
      await tester.pump();
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.tap(save);
      await tester.pump();
      expect(find.text('Сохраняем имя профиля…'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Сохраняем…'), findsOneWidget);

      state.saveCompleter.complete();
      await tester.pumpAndSettle();
      expect(find.text('Имя профиля сохранено.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить профиль'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('announces profile loading status', (tester) async {
    final state = AppState(ApiClient())..profileLoading = true;
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final loading = find.text('Загружаем профиль…');
    expect(loading, findsOneWidget);
    expect(tester.getSemantics(loading).flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('shows the app version and build number in profile settings', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-about')));
    await tester.pumpAndSettle();

    expect(find.text(appVersionLabel), findsOneWidget);
  });

  test(
    'app version label stays synchronized with the package release version',
    () {
      final packageVersion = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())?.group(1);

      expect(packageVersion, '$appVersionName+$appBuildNumber');
      expect(appVersionLabel, 'Версия $appVersionName ($appBuildNumber)');
    },
  );

  testWidgets('announces profile loading errors accessibly', (tester) async {
    final state = AppState(ApiClient())
      ..profileLoadError = 'Не удалось загрузить профиль.';
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final error = find.text('Не удалось загрузить профиль.');
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
    expect(find.text('Изменить пароль'), findsNothing);
  });

  testWidgets('explains generic native notification privacy', (tester) async {
    final state =
        AppState(
            ApiClient(),
            nativeNotifications: NativeNotificationService(
              supportedOnCurrentPlatform: true,
            ),
          )
          ..profile = const OwnProfile(
            accountId: 'account-1',
            login: 'member',
            displayName: 'Участник',
            role: 'MEMBER',
          );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('Уведомления'), findsNWidgets(2));
    expect(
      find.textContaining('Содержимое личных сообщений не отображается.'),
      findsOneWidget,
    );
  });

  testWidgets('profile name field leaves web code point validation to save', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField).first).maxLength,
      isNull,
    );
    expect(
      tester
          .widget<AuthenticatedAvatar>(find.byType(AuthenticatedAvatar))
          .radius,
      36,
    );
    expect(
      tester
          .widget<ConstrainedBox>(
            find.byKey(const ValueKey('profile-name-form-width')),
          )
          .constraints
          .maxWidth,
      480,
    );
  });

  testWidgets('centers profile content at web desktop max width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(ApiClient());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final content = tester.getRect(
      find.byKey(const ValueKey('profile-settings-content')),
    );
    expect(content.width, 720);
    expect(content.left, 360);
  });

  testWidgets(
    'uses web compact inset and full profile width on Android sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileScreen(state: state)),
        ),
      );

      final content = tester.getRect(
        find.byKey(const ValueKey('profile-settings-content')),
      );
      expect(content.width, 358);
      expect(content.left, 16);
    },
  );

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'profile settings keep save reachable at $width px with 2x text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = AppState(ApiClient())
          ..profile = const OwnProfile(
            accountId: 'account-1',
            login: 'длинныйлогиндлинныйлогиндлинныйлогиндлинныйлогин',
            displayName: 'ОООООООООООООООООООООООООООООООООООООООООООООООООООООООООООООООО',
            role: 'ADMINISTRATOR',
          );
        addTearDown(state.dispose);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(body: ProfileScreen(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        final save = find.widgetWithText(FilledButton, 'Сохранить профиль');
        expect(save, findsOneWidget);
        await tester.ensureVisible(save);
        final saveRect = tester.getRect(save);
        expect(saveRect.left, greaterThanOrEqualTo(0));
        expect(saveRect.right, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('profile save remains reachable with the system keyboard open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'long-member-login',
        displayName: 'Длинное отображаемое имя участника',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Сохранить профиль');
    await tester.ensureVisible(save);
    expect(tester.getRect(save).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(save).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile settings reflow when a desktop window becomes compact', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'long-member-login',
        displayName: 'Длинное отображаемое имя участника',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    final content = find.byKey(const ValueKey('profile-settings-content'));
    expect(tester.getRect(content).width, 720);

    tester.view.physicalSize = const Size(320, 844);
    await tester.pumpAndSettle();

    expect(tester.getRect(content).width, 288);
    final save = find.widgetWithText(FilledButton, 'Сохранить профиль');
    await tester.ensureVisible(save);
    expect(tester.getRect(save).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('moves keyboard focus to the profile heading like web', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final state = AppState(ApiClient());
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widget<Focus>(
            find.byKey(const ValueKey('profile-screen-title-focus')),
          )
          .focusNode
          ?.hasFocus,
      isTrue,
    );
    expect(
      tester
          .getSemantics(
            find.descendant(
              of: find.byKey(const ValueKey('profile-screen-title-focus')),
              matching: find.text('Настройки'),
            ),
          )
          .flagsCollection
          .isHeader,
      isTrue,
    );
    final titleStyle = tester.widget<Text>(find.text('Настройки')).style!;
    expect(titleStyle.fontSize, GcTypography.page);
    expect(titleStyle.height, GcTypography.pageLine / GcTypography.page);
    expect(titleStyle.fontWeight, GcTypography.bold);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    final compactTitleStyle = tester
        .widget<Text>(find.text('Настройки'))
        .style!;
    expect(compactTitleStyle.fontSize, GcTypography.pageCompact);
    expect(
      compactTitleStyle.height,
      GcTypography.pageCompactLine / GcTypography.pageCompact,
    );
    expect(find.text('Ваш профиль и параметры приложения.'), findsOneWidget);
  });

  testWidgets('profile mutation errors are announced as live regions', (
    tester,
  ) async {
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      )
      ..error = 'Имя должно содержать от 1 до 64 символов.';
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );

    final error = find.text('Имя должно содержать от 1 до 64 символов.');
    await tester.scrollUntilVisible(
      error,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(error, findsOneWidget);
    expect(tester.getSemantics(error).flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('profile settings use the web tab layout and selected panels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = AppState(ApiClient())
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-tabs-semantics')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('profile-tabs-semantics')))
          .getSemanticsData()
          .role,
      SemanticsRole.tabBar,
    );
    for (final entry in const {
      'profile': 'Профиль',
      'security': 'Безопасность',
      'notifications': 'Уведомления',
      'about': 'О приложении',
    }.entries) {
      final data = tester
          .getSemantics(find.byKey(ValueKey('profile-tab-${entry.key}')))
          .getSemanticsData();
      expect(data.label, entry.value, reason: entry.key);
      expect(data.role, SemanticsRole.tab);
    }
    expect(find.byKey(const ValueKey('profile-tab-profile')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('profile-tab-profile')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
    await tester.pumpAndSettle();
    expect(find.text('Изменить пароль'), findsOneWidget);
    expect(find.text('Отображаемое имя'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-tab-notifications')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Содержимое личных сообщений не отображается.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('profile-tab-about')));
    await tester.pumpAndSettle();
    expect(find.text(appVersionLabel), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('profile logout requires an explicit confirmation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _LogoutTrackingState()
      ..phase = AppPhase.ready
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(OutlinedButton, 'Выйти из аккаунта');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(find.text('Подтвердите выход из аккаунта'), findsOneWidget);
    expect(state.logoutCalls, 0);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Подтвердите выход из аккаунта'), findsNothing);
    expect(state.logoutCalls, 0);
    expect(state.phase, AppPhase.ready);
  });

  testWidgets('confirmed profile logout starts session shutdown', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _LogoutTrackingState()
      ..phase = AppPhase.ready
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(OutlinedButton, 'Выйти из аккаунта');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выйти'));
    await tester.pumpAndSettle();

    expect(state.logoutCalls, 1);
  });

  testWidgets('account change closes a stale logout confirmation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _LogoutTrackingState()
      ..phase = AppPhase.ready
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(OutlinedButton, 'Выйти из аккаунта');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.text('Подтвердите выход из аккаунта'), findsOneWidget);

    state.profile = const OwnProfile(
      accountId: 'account-2',
      login: 'another-member',
      displayName: 'Другой участник',
      role: 'MEMBER',
    );
    state.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('Подтвердите выход из аккаунта'), findsNothing);
    expect(state.logoutCalls, 0);
  });

  testWidgets('logout asks before discarding an unsaved profile name', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = _LogoutTrackingState()
      ..phase = AppPhase.ready
      ..profile = const OwnProfile(
        accountId: 'account-1',
        login: 'member',
        displayName: 'Участник',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(state: state)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Новое имя');
    await tester.tap(find.byKey(const ValueKey('profile-tab-security')));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(OutlinedButton, 'Выйти из аккаунта');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(find.text('Несохранённые изменения'), findsOneWidget);
    expect(find.text('Подтвердите выход из аккаунта'), findsNothing);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(state.logoutCalls, 0);
    await tester.tap(find.byKey(const ValueKey('profile-tab-profile')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Новое имя',
    );
  });
}
