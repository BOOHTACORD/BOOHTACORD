import 'dart:io';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class A11yTls extends HttpOverrides {
  A11yTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4930 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual native accessibility routes, semantics and 2x text', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4930/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA config required');
    }
    HttpOverrides.global = A11yTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final semantics = tester.ensureSemantics();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', origin);
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    final report = <String, dynamic>{
      'issue': 301,
      'status': 'RUNNING',
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'physical_device': false,
      'actual_api': true,
      'mocks': false,
      'spoken_screen_reader': 'NOT_RUN',
      'checks': <String, String>{},
      'measurements': <Map<String, dynamic>>[],
      'semantics': <Map<String, dynamic>>[],
    };
    final checks = report['checks'] as Map<String, String>;
    binding.reportData = {...?binding.reportData, 'accessibility_qa': report};
    String phase = 'login';
    void mark(String value) {
      phase = value;
      debugPrint('QA301_PHASE: $value');
    }

    Future<void> settle() async {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(tester.takeException(), isNull);
    }

    Future<void> waitFor(bool Function() condition) async {
      for (var n = 0; n < 150 && !condition(); n++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), true, reason: phase);
    }

    void scanSemantics(String name) {
      var buttons = 0, fields = 0, unnamedButtons = 0, unnamedFields = 0;
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (!node.isMergedIntoParent &&
            !node.isInvisible &&
            !data.flagsCollection.isHidden &&
            !node.rect.isEmpty) {
          if (data.flagsCollection.isButton &&
              data.hasAction(SemanticsAction.tap)) {
            buttons++;
            if (data.label.trim().isEmpty && data.tooltip.trim().isEmpty) {
              unnamedButtons++;
            }
          }
          if (data.flagsCollection.isTextField) {
            fields++;
            if (data.label.trim().isEmpty) unnamedFields++;
          }
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      final root = tester
          .binding
          .renderViews
          .first
          .owner
          ?.semanticsOwner
          ?.rootSemanticsNode;
      expect(root, isNotNull);
      visit(root!);
      (report['semantics'] as List).add({
        'scenario': name,
        'button_count': buttons,
        'field_count': fields,
        'unnamed_buttons': unnamedButtons,
        'unnamed_fields': unnamedFields,
      });
      if (name != 'native-failure') {
        expect(
          unnamedButtons,
          0,
          reason: '$name actionable button labels or tooltips',
        );
        expect(unnamedFields, 0, reason: '$name field names');
      }
    }

    var androidSurfaceConverted = false;
    Future<void> capture(String name) async {
      await settle();
      scanSemantics(name);
      if (Platform.isAndroid && !androidSurfaceConverted) {
        await binding.convertFlutterSurfaceToImage();
        androidSurfaceConverted = true;
      }
      final future = binding.takeScreenshot(name);
      var done = false;
      future.whenComplete(() => done = true);
      for (var i = 0; i < 60 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }
      await future.timeout(const Duration(seconds: 15));
    }

    Future<void> closeNav() async {
      final target = find.byTooltip('Закрыть навигацию').hitTestable();
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target);
        await settle();
      }
    }

    Future<void> nav() async {
      await closeNav();
      await tester.tap(find.byTooltip('Открыть навигацию').hitTestable().first);
      await settle();
    }

    Future<void> panel(String label) async {
      await nav();
      await tester.tap(find.byTooltip('Настройки аккаунта'));
      await settle();
      await tester.tap(find.text(label).last);
      await settle();
    }

    void named(Finder target, String expected, {bool tap = true}) {
      final data = tester.getSemantics(target).getSemanticsData();
      expect('${data.label} ${data.tooltip}', contains(expected));
      if (tap) expect(data.hasAction(SemanticsAction.tap), true);
      (report['semantics'] as List).add({
        'expected_label': expected,
        'name_present': true,
        'tap_action': data.hasAction(SemanticsAction.tap),
        'is_button': data.flagsCollection.isButton,
        'selected': data.flagsCollection.isSelected.name,
      });
    }

    Future<void> scaleCapture(String label) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await settle();
      await capture('$label-2x');
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await settle();
      (report['measurements'] as List).add({
        'scenario': label,
        'text_scale': 2,
        'method':
            'actual running native app; Flutter engine text-scale override',
        'layout_exception': false,
      });
    }

    try {
      mark('startup initialize');
      await tester.runAsync(state.initialize);
      if (state.phase == AppPhase.ready) {
        await tester.runAsync(state.logout);
      }
      expect(state.phase, AppPhase.signedOut);
      await tester.pumpWidget(BoohtacordApp(state: state));
      await settle();
      mark('login');
      final fields = find.byType(TextField);
      final passwordSemantics = tester
          .getSemantics(fields.at(1))
          .getSemanticsData();
      expect(passwordSemantics.flagsCollection.isTextField, true);
      expect(passwordSemantics.flagsCollection.isObscured, true);
      (report['semantics'] as List).add({
        'scenario': 'login password',
        'text_field': true,
        'obscured': true,
      });
      await tester.enterText(fields.at(0), 'qa_admin');
      await tester.enterText(fields.at(1), password);
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await waitFor(() => state.phase == AppPhase.ready);
      await settle();
      mark('guild navigation');
      await nav();
      named(find.byTooltip('Закрыть навигацию'), 'Закрыть навигацию');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await capture('native-guild-navigation');
      await scaleCapture('native-navigation');
      await tester.tap(find.text('AccessText').hitTestable().last);
      await settle();
      checks['guild_native_navigation_named_keyboard'] = 'PASS';
      mark('chat composer');
      final composer = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.hintText == 'Написать сообщение…',
      );
      expect(composer, findsOneWidget);
      expect(
        tester.getSemantics(composer).getSemanticsData().label,
        isNotEmpty,
      );
      await tester.tap(composer);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle();
      FocusManager.instance.primaryFocus?.unfocus();
      await capture('native-chat-composer');
      await scaleCapture('native-chat');
      checks['chat_native_semantics_2x'] = 'PASS';
      mark('DM navigation');
      await nav();
      await tester.tap(find.text('Личные').last);
      await settle();
      await tester.tap(find.text('qa_a11y_peer').hitTestable().first);
      await waitFor(() => state.selectedDirectMessage != null);
      await settle();
      expect(composer, findsOneWidget);
      await capture('native-dm');
      await scaleCapture('native-dm');
      checks['dm_native_route_semantics_2x'] = 'PASS';
      mark('admin seven tabs');
      await panel('Администрирование');
      await waitFor(
        () => find
            .byKey(const ValueKey('admin-member-search'))
            .evaluate()
            .isNotEmpty,
      );
      await settle();
      for (final section in [
        'guild',
        'members',
        'roles',
        'channels',
        'audit',
        'media',
        'readiness',
      ]) {
        final target = find.byKey(ValueKey('admin-section-tab-$section'));
        await tester.ensureVisible(target);
        await settle();
        final data = tester.getSemantics(target).getSemanticsData();
        expect(data.label, isNotEmpty);
        expect(data.hasAction(SemanticsAction.tap), true);
        await tester.tap(target);
        await settle();
        expect(
          tester
              .getSemantics(target)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
      }
      await capture('native-admin-tabs');
      await scaleCapture('native-admin');
      checks['seven_admin_tabs_named_selected_2x'] = 'PASS';
      mark('settings tabs');
      await panel('Профиль');
      await waitFor(() => find.text('Отображаемое имя').evaluate().isNotEmpty);
      await settle();
      for (final tab in [
        'Уведомления',
        'О приложении',
        'Безопасность',
        'Профиль',
      ]) {
        final target = find.text(tab);
        await tester.ensureVisible(target);
        await settle();
        await tester.tap(target);
        await settle();
      }
      await capture('native-settings');
      await scaleCapture('native-settings');
      checks['settings_native_tabs_2x'] = 'PASS';
      mark('logout dialog keyboard');
      final security = find.text('Безопасность');
      await tester.ensureVisible(security);
      await settle();
      await tester.tap(security);
      await settle();
      final logout = find.text('Выйти из аккаунта');
      await tester.ensureVisible(logout);
      await settle();
      await tester.tap(logout);
      await settle();
      expect(find.text('Подтвердите выход из аккаунта'), findsOneWidget);
      final cancel = find.widgetWithText(TextButton, 'Отмена');
      named(cancel, 'Отмена');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settle();
      await capture('native-dialog');
      await scaleCapture('native-dialog');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      expect(find.text('Подтвердите выход из аккаунта'), findsNothing);
      checks['native_dialog_keyboard_cancel_escape_2x'] = 'PASS';
      mark('voice prejoin');
      final voiceChannel = state.topology!.categories
          .expand((category) => category.channels)
          .singleWhere((channel) => channel.name == 'AccessVoice');
      await state.selectChannel(voiceChannel);
      await settle();
      report['voice_prejoin_navigation_method'] = 'Controlled production state.selectChannel of actual ACL-loaded channel; mobile channel-row pointer autojoin is not this prejoin test.';
      final listen = find.widgetWithText(
        OutlinedButton,
        'Подключиться без микрофона',
      );
      named(listen, 'Подключиться без микрофона');
      await capture('native-voice-prejoin');
      await scaleCapture('native-voice');
      checks['native_voice_prejoin_names_2x'] = 'PASS';
      if (Platform.isAndroid) {
        mark('actual voice stream setup');
        await tester.tap(listen);
        await waitFor(() => state.voicePhase == VoicePhase.listener);
        report['actual_sfu'] = true;
        await settle();
        final start = find
            .byTooltip('Начать демонстрацию экрана')
            .hitTestable()
            .first;
        named(start, 'Начать демонстрацию экрана');
        await tester.tap(start);
        await settle();
        expect(find.text('Демонстрация экрана'), findsWidgets);
        await capture('native-stream-setup');
        await scaleCapture('native-stream');
        await tester.tap(find.widgetWithText(TextButton, 'Отмена').hitTestable().first);
        await waitFor(() => find.text('Демонстрация экрана').evaluate().isEmpty);
        await settle();
        checks['native_stream_setup_names_2x'] = 'PASS';
        await tester.tap(
          find.byTooltip('Выйти из голосового канала').hitTestable().first,
        );
        await waitFor(
          () => state.voicePhase == VoicePhase.idle && state.room == null,
        );
        report['actual_voice_cleanup'] = 'PASS';
      } else {
        checks['native_stream_setup_names_2x'] = 'NOT_RUN';
        report['stream_limit'] = 'Known same-device iOS27 AURemoteIO SIGABRT after actual voice join in prior #247 cleanboot diagnostic; no blind media retry.';
      }
      report['status'] = checks.values.contains('NOT_RUN') ? 'PARTIAL' : 'PASS';
      mark('complete');
    } catch (error) {
      report['status'] = 'FAIL';
      report['failed_at'] = phase;
      report['error_type'] = error.runtimeType.toString();
      try {
        await capture('native-failure');
      } catch (_) {
        report['failure_capture'] = 'NOT_RUN';
      }
      rethrow;
    } finally {
      semantics.dispose();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      binding.reportData = {...?binding.reportData, 'accessibility_qa': report};
    }
  });
}
