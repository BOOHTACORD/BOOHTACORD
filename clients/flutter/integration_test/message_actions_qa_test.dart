import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_action_menu/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/direct_message_action_menu/component.dart';

import 'profile_revision/fixture.dart';

class ActionTls extends HttpOverrides {
  ActionTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4810 &&
            sha256.convert(cert.der).toString() == pin;
}

class ActionObserved extends http.BaseClient {
  final delegate = http.Client();
  int patches = 0, deletes = 0;
  final statuses = <String, List<int>>{};
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final action =
        request.url.path.contains('/messages/') &&
        ['PATCH', 'DELETE'].contains(request.method);
    if (action) {
      if (request.method == 'PATCH') patches++;
      if (request.method == 'DELETE') deletes++;
    }
    final response = await delegate.send(request);
    if (action) (statuses[request.method] ??= []).add(response.statusCode);
    return response;
  }

  @override
  void close() => delegate.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual native TEXT and DM action menus and HTTP outcomes', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4810/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA inputs required');
    }
    HttpOverrides.global = ActionTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final admin = FixtureSession(origin),
        a = FixtureSession(origin),
        b = FixtureSession(origin);
    for (final session in [admin, a, b]) {
      addTearDown(session.close);
    }
    final report = <String, Object?>{
      'issue': 293,
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'physical_device': false,
      'mocks': false,
      'fixture': 'Invisible synthetic message content; no body text or attachment payload in captures',
      'checks': <String, String>{},
      'viewport': {
        'physical_width': tester.view.physicalSize.width,
        'physical_height': tester.view.physicalSize.height,
        'device_pixel_ratio': tester.view.devicePixelRatio,
      },
    };
    final checks = report['checks'] as Map<String, String>;
    var phase = 'setup';
    Future<T> real<T>(Future<T> Function() task) async =>
        (await tester.runAsync<T>(task)) as T;
    Future<void> waitFor(bool Function() condition) async {
      for (var n = 0; n < 150 && !condition(); n++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
      }
      expect(condition(), true);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', origin);
    final observed = ActionObserved(),
        state = AppState(ApiClient(client: observed));
    addTearDown(state.dispose);
    try {
      await real(() => admin.login('qa_admin', password));
      await real(
        () => admin.json(
          'POST',
          '/auth/register',
          body: {'login': 'qa_native_actions_a', 'password': password},
          status: 201,
        ),
      );
      final peer = await real(
        () => admin.json(
          'POST',
          '/auth/register',
          body: {'login': 'qa_native_actions_b', 'password': password},
          status: 201,
        ),
      );
      final category = await real(
        () => admin.json(
          'POST',
          '/admin/categories',
          body: {'name': 'ActionsLab'},
          status: 201,
        ),
      );
      final channel = await real(
        () => admin.json(
          'POST',
          '/admin/categories/${category['id']}/channels',
          body: {'name': 'ActionsText', 'kind': 'TEXT'},
          status: 201,
        ),
      );
      await real(() => a.login('qa_native_actions_a', password));
      await real(() => b.login('qa_native_actions_b', password));
      final dm = await real(
        () => a.json(
          'POST',
          '/direct-messages',
          body: {'participant_id': peer['id']},
          status: 201,
        ),
      );
      final scopes = [
        '/channels/${channel['id']}',
        '/direct-messages/${dm['id']}',
      ];
      final own = <Map<String, dynamic>>[], foreign = <Map<String, dynamic>>[];
      for (final prefix in scopes) {
        own.add(
          await real(
            () => a.json(
              'POST',
              '$prefix/messages',
              body: {'body': '\u200b', 'client_message_id': const Uuid().v4()},
              status: 201,
            ),
          ),
        );
        foreign.add(
          await real(
            () => b.json(
              'POST',
              '$prefix/messages',
              body: {
                'body': '\u200b\u200b\u200b',
                'client_message_id': const Uuid().v4(),
              },
              status: 201,
            ),
          ),
        );
      }
      await tester.pumpWidget(BoohtacordApp(state: state));
      await real(state.initialize);
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'qa_native_actions_a',
      );
      await tester.enterText(find.byType(TextFormField).at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('Войти').last);
      await waitFor(() => state.phase == AppPhase.ready);
      await tester.pumpAndSettle();
      Finder trigger(String id, bool direct) => find.descendant(
        of: find.byWidgetPredicate(
          (w) => direct
              ? w is WorkspaceDirectMessageActionMenu && w.message.id == id
              : w is WorkspaceMessageActionMenu && w.message.id == id,
        ),
        matching: find.byTooltip('Действия с сообщением'),
      );
      for (var i = 0; i < scopes.length; i++) {
        final direct = i == 1,
            name = i == 1 ? 'DM' : 'TEXT',
            id = own[i]['id'] as String;
        phase = '$name navigation and actual history';
        if (direct) {
          await real(
            () => state.openDirectConversation(
              state.directMessages.firstWhere((d) => d.id == dm['id']),
            ),
          );
        } else {
          await real(
            () => state.selectChannel(
              state.topology!.categories
                  .expand((c) => c.channels)
                  .firstWhere((c) => c.id == channel['id']),
            ),
          );
        }
        await tester.pumpAndSettle();
        await waitFor(
          () => direct
              ? state.directMessageHistory.any((m) => m.id == id)
              : state.messages.any((m) => m.id == id),
        );
        final closeNavigation = find
            .byTooltip('Закрыть навигацию')
            .hitTestable();
        if (closeNavigation.evaluate().isNotEmpty) {
          await tester.tap(closeNavigation);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(trigger(id, direct));
        expect(trigger(id, direct).hitTestable(), findsOneWidget);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(trigger(id, direct)).width,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(trigger(id, direct)).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(trigger(id, direct));
        await tester.pumpAndSettle();
        report['${name}_menu_item_count'] = find
            .byType(PopupMenuItem<String>)
            .evaluate()
            .length;
        expect(
          tester
              .widgetList<PopupMenuItem<String>>(
                find.byType(PopupMenuItem<String>),
              )
              .map((w) => w.value),
          ['reply', 'edit', 'delete'],
        );
        await binding.takeScreenshot('${name.toLowerCase()}-owned-actions');
        checks['${name}_explicit_actions_targets'] = 'PASS';
        phase = '$name Reply and cancellation';
        await tester.tap(find.text('Ответить'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('reply-target-banner')),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('reply-target-banner')),
            matching: find.text('Отмена'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuItem<String>), findsNothing);
        checks['${name}_reply_and_cancel'] = 'PASS';
        phase = '$name edit real HTTP';
        await tester.tap(trigger(id, direct));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Изменить'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          '\u200b\u200b',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final patches = observed.patches;
        await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
        await waitFor(
          () =>
              observed.patches == patches + 1 &&
              observed.statuses['PATCH']?.last == 200,
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        checks['${name}_edit_HTTP_200'] = 'PASS';
        phase = '$name delete cancel then confirm';
        final deletes = observed.deletes;
        await tester.tap(trigger(id, direct));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        await binding.takeScreenshot(
          '${name.toLowerCase()}-delete-confirmation',
        );
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        expect(observed.deletes, deletes);
        await tester.tap(trigger(id, direct));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
        await waitFor(
          () =>
              observed.deletes == deletes + 1 &&
              observed.statuses['DELETE']?.last == 204,
        );
        await tester.pumpAndSettle();
        final history = await real(
          () => a.json('GET', '${scopes[i]}/messages?at=$id&limit=20'),
        );
        expect(
          (history['messages'] as List).any(
            (m) => m['id'] == id && m['deleted'] == true,
          ),
          true,
        );
        expect(trigger(id, direct), findsNothing);
        checks['${name}_delete_cancel_then_once_HTTP_204'] = 'PASS';
        phase = '$name peer ownership';
        final peerId = foreign[i]['id'] as String;
        await tester.ensureVisible(trigger(peerId, direct));
        await tester.pumpAndSettle();
        await tester.tap(trigger(peerId, direct));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<PopupMenuItem<String>>(
                find.byType(PopupMenuItem<String>),
              )
              .map((w) => w.value),
          ['reply'],
        );
        await binding.takeScreenshot('${name.toLowerCase()}-peer-actions');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        checks['${name}_peer_only_reply'] = 'PASS';
      }
      final denied = await real(
        () => admin.request('GET', '${scopes[1]}/messages'),
      );
      expect(denied.statusCode, 404);
      checks['DM_third_admin_history_denied'] = 'PASS';
      report['mutation_counts'] = {
        'PATCH': observed.patches,
        'DELETE': observed.deletes,
      };
      report['http_statuses'] = observed.statuses;
      await real(state.logout);
      await tester.pumpAndSettle();
      report['status'] = 'PARTIAL';
      report['remaining'] = [
        'physical touch/keyboard/spoken screen reader',
        'native reactions/pin/attachment and scroll/swipe/retry states not exercised',
      ];
    } catch (error, stack) {
      report['status'] = 'FAIL';
      report['failed_phase'] = phase;
      report['error_type'] = error.runtimeType.toString();
      report['failed_test_line'] = RegExp(
        r'message_actions_qa_test.dart:(\d+):',
      ).firstMatch(stack.toString())?.group(1);
      binding.reportData = {
        ...?binding.reportData,
        'message_actions_qa': report,
      };
      throw StateError(
        'Sanitized native message-actions phase $phase (${error.runtimeType})',
      );
    }
    binding.reportData = {...?binding.reportData, 'message_actions_qa': report};
  });
}
