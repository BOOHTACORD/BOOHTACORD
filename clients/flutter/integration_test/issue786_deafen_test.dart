import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/voice/microphone/deafen.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';

import 'issue689_support.dart';
import 'issue689_voice_fixture.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('voice deafen publishes lease state into the v2 roster', (
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
    if (Platform.isWindows) SharedPreferences.setMockInitialValues({});
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

    final channel = await createVoiceFixture(
      tester,
      api,
      app,
      categoryName: 'Deafen QA',
      channelName: 'Deafen voice',
    );
    await tester.runAsync(() => app.joinVoice(channel, listenerOnly: true));
    await waitFor(
      tester,
      () =>
          app.voiceRoster.phase == VoiceRosterPhase.fresh &&
          app.voiceRosters?.any(
                (room) =>
                    room.channelId == channel.id &&
                    room.participants.any(
                      (member) =>
                          member.accountId == app.user?.accountId &&
                          !member.deafened,
                    ),
              ) ==
              true,
    );

    await tester.runAsync(app.voice.toggleDeafen);
    await waitFor(
      tester,
      () =>
          app.voice.deafened &&
          app.voiceRosters?.any(
                (room) =>
                    room.channelId == channel.id &&
                    room.participants.any(
                      (member) =>
                          member.accountId == app.user?.accountId &&
                          member.deafened,
                    ),
              ) ==
              true,
    );
    await tester.pumpAndSettle();
    if (Platform.isAndroid || Platform.isIOS) {
      await binding.takeScreenshot('issue786-deafened-v2-roster');
    }

    await tester.runAsync(app.voice.toggleDeafen);
    await waitFor(
      tester,
      () =>
          !app.voice.deafened &&
          app.voiceRosters?.any(
                (room) =>
                    room.channelId == channel.id &&
                    room.participants.any(
                      (member) =>
                          member.accountId == app.user?.accountId &&
                          !member.deafened,
                    ),
              ) ==
              true,
    );
    await tester.runAsync(app.leaveVoice);
    await waitFor(
      tester,
      () => app.voicePhase == VoicePhase.idle && app.room == null,
    );
    expect(api.legacyRequests, 0);
    expect(tester.takeException(), isNull);
  });
}
