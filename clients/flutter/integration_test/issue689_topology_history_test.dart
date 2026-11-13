import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/conversation/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/workspace/lifecycle/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'issue689_support.dart' show waitFor;
import 'issue689_topology_history_api.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native topology history ignores a response after socket end', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE');
    const pin = String.fromEnvironment('QA_CERT_SHA256');
    const password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4810/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError(
        'Owned QA endpoint, certificate pin and disposable credentials required',
      );
    }
    HttpOverrides.global = QaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('server_url', origin);
    final api = DelayedHistoryApi();
    final app = AppState(api);
    addTearDown(app.dispose);
    await tester.pumpWidget(BoohtacordApp(state: app));
    await tester.runAsync(app.initialize);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'qa_admin');
    await tester.enterText(fields.at(1), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Войти').last);
    await waitFor(
      tester,
      () =>
          app.phase == AppPhase.ready &&
          app.realtime.connected &&
          app.workspace.topology != null,
    );
    final channel = app.workspace.topology!.categories
        .expand((category) => category.channels)
        .firstWhere((channel) => channel.kind == ChannelKind.text);
    final priorTopologies = api.completedTopologies;
    await tester.runAsync(() async {
      await app.workspace.selectChannel(channel);
      await api.sendMessage(
        channel.id,
        '11111111-1111-4111-8111-111111111111',
        'Synthetic history fence',
      );
    });
    await waitFor(
      tester,
      () =>
          api.completedTopologies > priorTopologies &&
          app.conversation.messages.any(
            (message) => message.body == 'Synthetic history fence',
          ),
    );
    await tester.runAsync(() async {
      app.workspace.selectedChannel = null;
      app.conversation.clearText();
      api.heldChannel = channel.id;
      final pending = app.workspace.refreshTopology(strict: true);
      await api.held.future.timeout(const Duration(seconds: 10));
      await app.realtime.close();
      api.release.complete();
      await pending;
    });
    expect(app.conversation.messages, isEmpty);
    expect(app.conversation.loadingMessages, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Synthetic history fence'), findsNothing);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('android-topology-history-fenced');
    }
    expect(tester.takeException(), isNull);
  });
}
