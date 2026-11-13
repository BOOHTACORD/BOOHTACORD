import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';

import 'issue689_support.dart';
import 'issue689_voice_fixture.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('listener survives application socket reconnect', (tester) async {
    const origin = String.fromEnvironment('QA_API_BASE');
    const pin = String.fromEnvironment('QA_CERT_SHA256');
    const password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4810/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA endpoint, pin and credentials required');
    }
    HttpOverrides.global = QaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('server_url', origin);
    final api = SocketOnlyApi();
    final app = AppState(api);
    addTearDown(app.dispose);
    await tester.pumpWidget(BoohtacordApp(state: app));
    await tester.runAsync(app.initialize);
    await tester.pumpAndSettle();
    await waitFor(
      tester,
      () => app.maintenanceKnown && api.publicSockets.isNotEmpty,
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'qa_admin');
    await tester.enterText(fields.at(1), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Войти').last);
    await waitFor(
      tester,
      () => app.phase == AppPhase.ready && app.realtime.connected,
    );
    final voice = await createVoiceFixture(
      tester,
      api,
      app,
      categoryName: 'Listener QA',
      channelName: 'Listener voice',
    );
    await tester.runAsync(() => app.joinVoice(voice, listenerOnly: true));
    await waitFor(
      tester,
      () => app.voicePhase == VoicePhase.listener && app.room != null,
    );
    final room = app.room;
    bool selfInRoster() =>
        app.voiceRosters?.any(
          (r) =>
              r.channelId == voice.id &&
              r.participants.any((p) => p.accountId == app.user?.accountId),
        ) ??
        false;
    await waitFor(
      tester,
      () => app.voiceRoster.phase == VoiceRosterPhase.fresh && selfInRoster(),
    );
    final socket = app.realtime.socket;
    await tester.runAsync(() => socket!.close());
    await waitFor(
      tester,
      () =>
          app.realtime.connected &&
          app.realtime.socket != socket &&
          app.voiceRoster.phase == VoiceRosterPhase.fresh &&
          selfInRoster(),
    );
    expect(app.room, same(room));
    expect(app.voicePhase, VoicePhase.listener);
    expect(api.legacyRequests, 0);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    if (Platform.isAndroid || Platform.isIOS) {
      await binding.takeScreenshot('native-listener-realtime-recovered');
    }
    await tester.runAsync(app.leaveVoice);
    await waitFor(
      tester,
      () => app.voicePhase == VoicePhase.idle && app.room == null,
    );
    await tester.runAsync(app.session.logout);
    await waitFor(
      tester,
      () =>
          app.phase == AppPhase.signedOut &&
          app.maintenanceKnown &&
          api.publicSockets.isNotEmpty &&
          api.publicSockets.last.readyState == WebSocket.open,
    );
    expect(tester.takeException(), isNull);
  });
}
