import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/admin/telemetry/panel.dart';
import 'package:boohtacord_desktop/src/features/conversation/reactions/api.dart';
import 'package:boohtacord_desktop/src/features/conversation/pins/api.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/message_social/controller.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/text_pins/controller.dart';

class OwnedParityTls extends HttpOverrides {
  OwnedParityTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4810 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'PAR-01/02/04 actual Go reconnect snapshots and reachable admin telemetry',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE'),
          pin = String.fromEnvironment('QA_CERT_SHA256'),
          password = String.fromEnvironment('QA_PASSWORD');
      expect(origin, 'https://localhost:4810/api/v1');
      expect(pin.length, 64);
      expect(password, isNotEmpty);
      HttpOverrides.global = OwnedParityTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', origin);
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      final api = ApiClient();
      // Use the same real API owner for every production feature and cookie scope.
      final app = AppState(api);
      addTearDown(app.dispose);
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 160 && !done(); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(done(), isTrue);
      }

      await tester.pumpWidget(BoohtacordApp(state: app));
      await tester.runAsync(app.initialize);
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
      await until(() => app.phase == AppPhase.ready && app.realtime.connected);
      await tester.pumpAndSettle();
      final closeNavigation = find.byTooltip('Закрыть навигацию').hitTestable();
      if (closeNavigation.evaluate().isNotEmpty) {
        await tester.tap(closeNavigation);
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        await api.createCategory('Parity QA');
        await app.refreshTopology();
        final category = app.topology!.categories.first;
        await api.createChannel(
          categoryId: category.id,
          name: 'Parity QA Text',
          kind: ChannelKind.text,
        );
        await app.refreshTopology();
      });
      await tester.pumpAndSettle();
      final channel = app.topology!.categories.first.channels.first;
      await tester.runAsync(() => app.selectChannel(channel));
      await tester.pumpAndSettle();
      final first = await tester.runAsync(
        () => api.sendMessage(channel.id, const Uuid().v4(), 'Parity original'),
      );
      await until(
        () =>
            app.messages.any((m) => m.id == first!.id) &&
            app.realtime.delivery.cursor != null,
      );
      final social = MessageSocialController(
        api.transport,
        false,
        channel.id,
        first!.id,
      );
      final pins = TextPinsController(api.transport, channel.id);
      addTearDown(social.dispose);
      addTearDown(pins.dispose);
      await tester.runAsync(() async {
        await social.load();
        await pins.load();
      });
      // Freeze only the current realtime socket; REST and the actual server remain
      // live. This intentionally exercises replay rather than resending UI commands.
      final cursor = app.realtime.delivery.cursor;
      await tester.runAsync(() => app.realtime.socket!.close());
      await until(() => !app.realtime.connected);
      app.realtime.retry?.cancel();
      app.realtime.retry = null;
      await tester.runAsync(() async {
        await api.editMessage(
          channel.id,
          first.id,
          'Parity updated while disconnected',
          first.revision,
        );
        final deleted = await api.sendMessage(
          channel.id,
          const Uuid().v4(),
          'Parity delete target',
        );
        await api.deleteMessage(channel.id, deleted.id);
        await ReactionApi(api.transport)
            .set(false, channel.id, first.id, '👍', true);
        await TextPinApi(api.transport).set(channel.id, first.id, true);
      });
      expect(app.realtime.delivery.cursor, cursor);
      app.realtime.retryNow();
      await until(
        () =>
            app.realtime.connected &&
            app.messages.any(
              (m) =>
                  m.id == first.id &&
                  m.body == 'Parity updated while disconnected',
            ) &&
            social.count('👍') == 1 &&
            pins.pins.any((p) => p.messageId == first.id),
      );
      expect(app.messages.map((m) => m.id).toSet().length, app.messages.length);
      expect(app.phase, AppPhase.ready);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('native-parity-replay');
      // A second account writes through the same real pair-only contract, using
      // an isolated in-memory HTTP cookie jar (never the native account keychain).
      final peer = HttpClient();
      addTearDown(() => peer.close(force: true));
      final peerCookies = <Cookie>[];
      Future<Map<String, dynamic>> peerCall(
        String method,
        String path, [
        Map<String, dynamic>? body,
      ]) async {
        final request = await peer.openUrl(method, Uri.parse('$origin$path'));
        request.headers.set('origin', 'https://localhost:4810');
        request.cookies.addAll(peerCookies);
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        if (path == '/auth/login') peerCookies.addAll(response.cookies);
        final value = await utf8.decoder.bind(response).join();
        final failure = response.statusCode >= 400 && value.startsWith('{')
            ? (jsonDecode(value) as Map<String, dynamic>)['error']
            : null;
        expect(
          response.statusCode,
          inInclusiveRange(200, 204),
          reason: failure is Map
              ? 'peer API error code: ${failure['code']}'
              : 'peer API request failed',
        );
        return value.isEmpty ? {} : jsonDecode(value) as Map<String, dynamic>;
      }

      late DirectConversation pair;
      await tester.runAsync(() async {
        await peerCall('POST', '/auth/login', {
          'login': 'qa_peer',
          'password': password,
        });
        final members = await api.members();
        final target = members.firstWhere((m) => m.id != app.user!.accountId);
        final signedPeer = await peerCall('GET', '/auth/session');
        expect(signedPeer['account_id'], target.id);
        final id = await api.openDirectMessage(target.id);
        await app.refreshDirectMessages();
        pair = app.directMessages.firstWhere((dm) => dm.id == id);
        await app.openDirectConversation(pair);
      });
      await tester.pumpAndSettle();
      final dm = await tester.runAsync(
        () => peerCall('POST', '/direct-messages/${pair.id}/messages', {
          'client_message_id': const Uuid().v4(),
          'body': 'Parity peer original',
        }),
      );
      final dmId = (dm!['message'] ?? dm)['id'] as String;
      await until(() => app.directMessageHistory.any((m) => m.id == dmId));
      await tester.runAsync(() => app.realtime.socket!.close());
      await until(() => !app.realtime.connected);
      app.realtime.retry?.cancel();
      app.realtime.retry = null;
      await tester.runAsync(
        () => peerCall('PATCH', '/direct-messages/${pair.id}/messages/$dmId', {
          'body': 'Parity peer replayed edit',
          'expected_revision': 1,
        }),
      );
      app.realtime.retryNow();
      await until(
        () =>
            app.realtime.connected &&
            app.directMessageHistory.any(
              (m) => m.id == dmId && m.body == 'Parity peer replayed edit',
            ),
      );
      expect(app.selectedDirectMessage?.id, pair.id);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('native-parity-dm-replay');
      app.toggleWorkspacePanel(WorkspacePanel.admin);
      await tester.pumpAndSettle();
      final guildTab = find.text('Гильдия').first;
      await tester.ensureVisible(guildTab);
      await tester.tap(guildTab);
      await tester.pumpAndSettle();
      expect(find.byType(AdminTelemetryPanel), findsOneWidget);
      final panel = find.byType(AdminTelemetryPanel);
      await tester.ensureVisible(panel);
      await tester.pumpAndSettle();
      // The source UI reaches the same GET state; opening never enrolls the centre.
      final settings = await tester.runAsync(api.readTelemetrySettings);
      expect(settings!.mode, 'local_only');
      expect(find.text('Диагностика установки'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Обновить состояние')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Обновить состояние'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Диагностика установки'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('native-parity-telemetry');
      expect(tester.takeException(), isNull);
      await tester.runAsync(app.logout);
      await tester.pumpAndSettle();
      expect(app.phase, AppPhase.signedOut);
      expect(app.realtime.delivery.cursor, isNull);
    },
  );
}
