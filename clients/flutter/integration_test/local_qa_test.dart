import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

class QaTls extends HttpOverrides {
  QaTls(this.pin);
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
  testWidgets('owned API authentication and native workspace visual smoke', (
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
    final api = ApiClient();
    final state = AppState(api);
    addTearDown(state.dispose);
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.runAsync(state.initialize);
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.signedOut);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('native-auth');
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'qa_admin');
    await tester.enterText(fields.at(1), password);
    // Dismiss the software keyboard before activating the visible login action.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Войти').last);
    for (
      var attempt = 0;
      attempt < 120 && state.phase != AppPhase.ready;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(state.phase, AppPhase.ready);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('native-navigation');
    await tester.tap(find.byTooltip('Закрыть навигацию'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
    await binding.takeScreenshot('native-workspace');
    for (final panel in [
      WorkspacePanel.profile,
      WorkspacePanel.audio,
      WorkspacePanel.admin,
    ]) {
      state.toggleWorkspacePanel(panel);
      await tester.pumpAndSettle();
      expect(state.workspacePanel, panel);
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot('native-${panel.name}');
    }
    state.showChannels();
    await tester.pumpAndSettle();
    await tester.runAsync(state.logout);
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.signedOut);
    await binding.takeScreenshot('native-signed-out');
  });
}
