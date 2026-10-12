import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/guild_quick_jump/component.dart';

import 'profile_revision/fixture.dart';

import 'package:boohtacord_desktop/src/features/workspace/quick_jump/state/controller.dart';

class QuickTls extends HttpOverrides {
  QuickTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4830 &&
            sha256.convert(cert.der).toString() == pin;
}

class ObservedClient extends http.BaseClient {
  final delegate = http.Client();
  int voiceMutations = 0, directWrites = 0;
  final historyStatuses = <int>[];
  final contextStatuses = <int>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.path.contains('/voice/') && request.method != 'GET') {
      voiceMutations++;
    }
    if (request.url.path.endsWith('/direct-messages') &&
        request.method == 'POST') {
      directWrites++;
    }
    return delegate.send(request).then((response) {
      if (request.url.path.contains('/direct-messages/') &&
          request.url.path.endsWith('/messages')) {
        historyStatuses.add(response.statusCode);
        if (request.url.queryParameters['at'] ==
            '00000000-0000-4000-8000-000000000000')
          contextStatuses.add(response.statusCode);
      }
      return response;
    });
  }

  @override
  void close() => delegate.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android quick jump authorized people and keyboard navigation',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE'),
          pin = String.fromEnvironment('QA_CERT_SHA256'),
          password = String.fromEnvironment('QA_PASSWORD');
      if (origin != 'https://localhost:4830/api/v1' ||
          pin.length != 64 ||
          password.isEmpty) {
        throw StateError('Owned QA inputs required');
      }
      HttpOverrides.global = QuickTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      final fixture = FixtureSession(origin), peer = FixtureSession(origin);
      addTearDown(fixture.close);
      addTearDown(peer.close);
      final report = <String, Object?>{
        'issue': 283,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'physical_device': false,
        'viewport': {
          'physical_width': tester.view.physicalSize.width,
          'physical_height': tester.view.physicalSize.height,
          'device_pixel_ratio': tester.view.devicePixelRatio,
        },
        'shortcut_initial_mode': 'messages',
        'os_version': Platform.operatingSystemVersion,
        'roles': ['ADMIN', 'MEMBER'],
        'checks': <String, String>{},
        'OS_notifications': 'NOT_RUN',
        'mocks': false,
      };
      final checks = report['checks'] as Map<String, String>;
      var phase = 'fixtures';
      Future<T> real<T>(Future<T> Function() action) async =>
          (await tester.runAsync<T>(action)) as T;
      Future<void> waitFor(bool Function() value) async {
        for (var i = 0; i < 150 && !value(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await tester.pump();
        }
        expect(value(), true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', origin);
      final observed = ObservedClient(),
          state = AppState(ApiClient(client: observed));
      addTearDown(state.dispose);
      try {
        await real(() => fixture.login('qa_admin', password));
        final b = await real(
          () => fixture.json(
            'POST',
            '/auth/register',
            body: {'login': 'qa_native_jump_b', 'password': password},
            status: 201,
          ),
        );
        final c = await real(
          () => fixture.json(
            'POST',
            '/auth/register',
            body: {'login': 'qa_native_jump_c', 'password': password},
            status: 201,
          ),
        );
        await real(() => peer.login('qa_native_jump_b', password));
        await real(
          () => peer.rename(
            'Тестовый участник 👩🏽‍💻 漢字 — длинное имя проверки',
          ),
        );
        await real(
          () => fixture.json(
            'POST',
            '/direct-messages',
            body: {'participant_id': b['id']},
            status: 201,
          ),
        );
        await tester.pumpWidget(BoohtacordApp(state: state));
        await real(state.initialize);
        await tester.pumpAndSettle();
        if (Platform.isAndroid) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pumpAndSettle();
        }
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'qa_admin');
        await tester.enterText(fields.at(1), password);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Войти').last);
        await waitFor(() => state.phase == AppPhase.ready);
        await tester.pumpAndSettle();
        phase = 'shortcut and separate navigation mode';
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(state.workspacePanel, WorkspacePanel.search);
        await tester.tap(find.byTooltip('Каналы и люди'));
        await tester.pumpAndSettle();
        final panel = find.byType(GuildQuickJumpPanel);
        await waitFor(
          () => tester.state<GuildQuickJumpState>(panel).owner.loaded,
        );
        final owner = tester.state<GuildQuickJumpState>(panel).owner;
        expect(
          owner.entries
              .where((e) => e.label.contains('Тестовый участник'))
              .length,
          1,
        );
        expect(find.text('Личное сообщение'), findsOneWidget);
        expect(find.text('Участник гильдии'), findsWidgets);
        await binding.takeScreenshot('native-quick-jump-people');
        checks['visible_MEMBER_vs_existing_DM_labels'] = 'PASS';
        checks['shortcut_separate_people_and_dedup'] = 'PASS';
        phase = 'actual keyboard new two-person DM';
        await tester.enterText(
          find.byKey(const ValueKey('guild-quick-jump-query')),
          'qa_native_jump_c',
        );
        await tester.pump();
        while (owner.entries.isEmpty && owner.canLoad) {
          await real(owner.load);
          await tester.pump();
        }
        expect(owner.entries.length, 1);
        final before = observed.directWrites;
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'qa_native_jump_c',
            selection: TextSelection.collapsed(offset: 16),
            composing: TextRange(start: 0, end: 16),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(observed.directWrites, before);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'qa_native_jump_c',
            selection: TextSelection.collapsed(offset: 16),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await waitFor(
          () => state.selectedDirectMessage?.participantId == c['id'],
        );
        await tester.pumpAndSettle();
        expect(observed.directWrites, before + 1);
        expect(state.workspacePanel, WorkspacePanel.none);
        expect(observed.voiceMutations, 0);
        expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
        await binding.takeScreenshot('native-authorized-dm-navigation');
        checks['DM_surface_not_obscured_by_navigation'] = 'PASS';
        checks['controlled_IME_then_Enter_authorized_DM_no_voice'] = 'PASS';
        phase = 'actual unavailable reply-context header';
        final directId = state.selectedDirectMessage!.id;
        await real(
          () => state.openSearchContext(
            SearchMessage(
              id: '00000000-0000-4000-8000-000000000000',
              kind: SearchMessageKind.directMessage,
              conversationId: directId,
              authorId: c['id'] as String,
              body: '',
              createdAt: DateTime.utc(2026),
              revision: 1,
            ),
            heading: 'Контекст ответа',
          ),
        );
        await tester.pumpAndSettle();
        expect(state.searchContextError, isNotNull);
        report['controlled_reply_context_statuses'] = observed.contextStatuses;
        report['context_error_present'] = state.searchContextError != null;
        expect(observed.contextStatuses, [200]);
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('native-unavailable-reply-context-header');
        await tester.tap(find.byTooltip('К последним сообщениям'));
        await tester.pumpAndSettle();
        expect(state.workspacePanel, WorkspacePanel.none);
        report['controlled_reply_context_history_status'] =
            observed.contextStatuses.single;
        checks['actual_unavailable_reply_context_header_no_overflow_Back'] = 'PASS';
        phase = 'Escape/disposal/reopen';
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Каналы и люди'));
        await tester.pumpAndSettle();
        final oldOwner = tester.state<GuildQuickJumpState>(panel).owner;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(state.workspacePanel, WorkspacePanel.none);
        expect(oldOwner.disposed, true);
        expect(oldOwner.people, isEmpty);
        checks['Escape_disposes_people'] = 'PASS';
        phase = 'logout and same-app account switch';
        await real(state.logout);
        await tester.pumpAndSettle();
        expect(state.phase, AppPhase.signedOut);
        await binding.takeScreenshot('native-logged-out');
        final inputs = find.byType(TextFormField);
        await tester.enterText(inputs.at(0), 'qa_native_jump_b');
        await tester.enterText(inputs.at(1), password);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Войти').last);
        await waitFor(() => state.phase == AppPhase.ready);
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Каналы и люди'));
        await tester.pumpAndSettle();
        final nextOwner = tester.state<GuildQuickJumpState>(panel).owner;
        await waitFor(() => nextOwner.loaded);
        expect(nextOwner.account, state.user?.accountId);
        expect(oldOwner.entries, isEmpty);
        await binding.takeScreenshot('native-account-switch-people');
        checks['same_app_switch_people_scope'] = 'PASS';
        await real(state.logout);
        await tester.pumpAndSettle();
        report['status'] = 'PARTIAL';
      } catch (error, stack) {
        final failedLine = RegExp(r'quick_jump_qa_test.dart:(\d+):')
            .firstMatch(stack.toString());
        if (failedLine != null)
          report['failed_test_line'] = int.parse(failedLine.group(1)!);
        report['status'] = 'FAIL';
        report['failed_phase'] = phase;
        report['error_type'] = error.runtimeType.toString();
        binding.reportData = {...?binding.reportData, 'quick_jump_qa': report};
        throw StateError(
          'Native quick jump phase $phase (${error.runtimeType})',
        );
      }
      binding.reportData = {...?binding.reportData, 'quick_jump_qa': report};
    },
  );
}
