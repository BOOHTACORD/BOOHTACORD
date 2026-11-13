import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/realtime/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';

import 'issue689_support.dart';
import 'issue689_voice_fixture.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native roster uses the authenticated socket and reconnects', (
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
    if (Platform.isWindows) {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    }
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
    expect(api.sockets, 0);
    await captureUnknownMaintenance(tester, binding, app);
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
          app.maintenanceKnown,
    );
    expect(
      api.publicSockets.every((socket) => socket.closed),
      isTrue,
      reason: 'Each guest close must complete before the authenticated socket is ready',
    );
    await createVoiceFixture(
      tester,
      api,
      app,
      categoryName: 'Roster QA',
      channelName: 'Roster voice',
    );
    await waitFor(
      tester,
      () =>
          app.voiceRoster.phase == VoiceRosterPhase.fresh &&
          (app.voiceRosters?.isNotEmpty ?? false),
    );
    final original = app.realtime.socket;
    await tester.runAsync(app.realtime.reconnectNow);
    await waitFor(
      tester,
      () =>
          app.realtime.connected &&
          app.realtime.socket != original &&
          app.voiceRoster.phase == VoiceRosterPhase.fresh,
    );
    expect(api.sockets, greaterThanOrEqualTo(2));
    expect(api.legacyRequests, 0);
    await tester.pumpAndSettle();
    if (!Platform.isWindows) {
      await binding.takeScreenshot('android-roster-socket');
    }
    await tester.runAsync(app.session.logout);
    await waitFor(
      tester,
      () =>
          app.phase == AppPhase.signedOut &&
          app.maintenanceKnown &&
          api.publicSockets.last.readyState == WebSocket.open,
    );
    expect(app.realtime.socket, isNull);
    expect(api.legacyRequests, 0);
    expect(tester.takeException(), isNull);
  });
}
