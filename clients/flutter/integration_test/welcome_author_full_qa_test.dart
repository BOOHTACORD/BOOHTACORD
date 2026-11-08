import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/system_welcome_author/component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'three_bugs/peer.dart';
import 'three_bugs/welcome_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('full workspace resolves an uncached historical welcome author', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE');
    const pin = String.fromEnvironment('QA_CERT_SHA256');
    const password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4810/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA endpoint required');
    }
    HttpOverrides.global = QaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('server_url', origin);
    final state = AppState(ApiClient());
    final captureKey = GlobalKey();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: BoohtacordApp(state: state),
      ),
    );
    await tester.runAsync(state.initialize);
    await tester.runAsync(
      () => state.authenticate('qa_admin', password, register: false),
    );
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.ready);
    await tester.runAsync(() async {
      final name = 'qa_welcome_${DateTime.now().millisecondsSinceEpoch}';
      await state.api.createCategory(name);
      final topology = await state.api.topology();
      final category = topology.categories.firstWhere((c) => c.name == name);
      await state.api.createChannel(
        categoryId: category.id,
        name: 'welcome',
        kind: ChannelKind.text,
      );
      await state.refreshTopology();
    });
    final channel = state.topology!.categories
        .expand((c) => c.channels)
        .firstWhere((c) => c.kind == ChannelKind.text);
    await tester.runAsync(() async {
      final settings = await state.api.readGuildSettings();
      await state.api.updateGuildSettings(
        settings.name,
        channel.id,
        settings.revision,
      );
    });
    final name =
        'qa_welcome_${DateTime.now().millisecondsSinceEpoch % 100000000}';
    final peer = (await tester.runAsync(() => QaPeer.start(origin, name)))!;
    await tester.runAsync(peer.close);
    await tester.runAsync(() => state.selectChannel(channel));
    for (
      var i = 0;
      i < 100 && find.byType(ResolvedSystemWelcome).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(ResolvedSystemWelcome), findsWidgets);
    state.members = state.members
        .where((member) => member.id != peer.id)
        .toList();
    state.notifyListeners();
    await tester.pump();
    final rich = find.descendant(
      of: find.byType(ResolvedSystemWelcome),
      matching: find.byType(RichText),
    );
    var resolved = false;
    for (var i = 0; i < 100 && !resolved; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      resolved = rich.evaluate().any(
        (element) =>
            (element.widget as RichText).text.toPlainText().contains('@$name '),
      );
    }
    expect(state.members.any((member) => member.id == peer.id), isFalse);
    expect(resolved, isTrue);
    const capturePath = String.fromEnvironment('QA_SCREENSHOT_PATH');
    if (capturePath.isNotEmpty) {
      await tester.runAsync(() => captureWelcome(captureKey, capturePath));
    }
    debugPrint('WELCOME_FULL_WORKSPACE_PASS uncached_author=true');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
