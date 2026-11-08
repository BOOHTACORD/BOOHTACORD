import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'three_bugs/auth.dart';
import 'three_bugs/peer.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('registration, live members and chat profile on a real API', (
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
    addTearDown(state.dispose);
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.runAsync(state.initialize);
    await tester.pumpAndSettle();
    await shortPasswordAndLogin(tester, binding, state, password);
    final peerName =
        'qa_peer_${DateTime.now().millisecondsSinceEpoch % 100000000}';
    expect(state.members.any((m) => m.login == peerName), isFalse);
    final channels = state.topology!.categories
        .expand((c) => c.channels)
        .where((c) => c.kind == ChannelKind.text);
    expect(channels, isNotEmpty);
    final channel = channels.first;
    await tester.runAsync(() => state.selectChannel(channel));
    await tester.pumpAndSettle();
    final closeNavigation = find.byTooltip('Закрыть навигацию');
    if (closeNavigation.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(closeNavigation.hitTestable().first);
      await tester.pumpAndSettle();
    }
    final peer = (await tester.runAsync(() => QaPeer.start(origin, peerName)))!;
    addTearDown(peer.close);
    for (
      var i = 0;
      i < 160 && !state.members.any((m) => m.id == peer.id);
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      state.members.any((m) => m.id == peer.id),
      isTrue,
      reason: 'new online user appears without manual refresh',
    );
    await tester.runAsync(() => peer.postMessage(channel.id));
    final trigger = find.byKey(ValueKey('member-profile-trigger:${peer.id}'));
    for (var i = 0; i < 160 && trigger.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(trigger, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(trigger), alignment: 0.5);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('three-bugs-android-chat');
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Сообщение'), findsOneWidget);
    await binding.takeScreenshot('three-bugs-android-profile');
    await tester.tap(find.text('Сообщение'));
    for (var i = 0; i < 160 && state.selectedDirectMessage == null; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(state.selectedDirectMessage?.participantId, peer.id);
    debugPrint(
      'THREE_BUGS_ANDROID_PASS short_password_blocked=true live_member=true chat_to_dm=true',
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}
