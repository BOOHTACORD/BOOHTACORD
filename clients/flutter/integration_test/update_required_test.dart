import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/app_version.dart';
import 'package:boohtacord_desktop/src/features/updates/api.dart';
import 'package:boohtacord_desktop/src/features/updates/controller.dart';
import 'package:boohtacord_desktop/src/features/updates/identity.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real API minimum shows required update and preserves form', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE');
    const pin = String.fromEnvironment('QA_CERT_SHA256');
    if (origin != 'https://localhost:4810/api/v1' || pin.length != 64) {
      throw StateError('Owned API and certificate pin required');
    }
    HttpOverrides.global = QaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('server_url', origin);
    final api = ApiClient();
    final state = AppState(api);
    addTearDown(state.dispose);
    final identity = await NativeUpdateIdentity.load();
    final updates = UpdateController(
      api: UpdateApi(baseUrl: () => origin),
      identity: identity,
    );
    addTearDown(updates.dispose);
    await tester.pumpWidget(BoohtacordApp(state: state, updates: updates));
    await tester.runAsync(state.initialize);
    await tester.pumpAndSettle();
    expect(state.phase, AppPhase.signedOut);
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, 'synthetic draft');
    await tester.runAsync(updates.check);
    await tester.pumpAndSettle();
    expect(updates.policy?.target?.minimumReleaseOrder, appReleaseOrder + 1);
    final gate = find.byKey(const ValueKey('required-update-gate'));
    expect(gate, findsOneWidget);
    expect(
      find.descendant(of: gate, matching: find.text('Требуется обновление')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gate, matching: find.text('Позже')),
      findsNothing,
    );
    expect(
      tester.widget<TextFormField>(fields.first).controller?.text,
      'synthetic draft',
    );
    expect(fields.first.hitTestable(), findsNothing);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot(
      Platform.isAndroid ? 'android-required-update' : 'ios-required-update',
    );
    if (Platform.isAndroid) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 8)),
      );
      await tester.pumpAndSettle();
      expect(gate, findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.first).controller?.text,
        'synthetic draft',
      );
      await binding.takeScreenshot('android-required-update-after-back');
    }
    expect(tester.takeException(), isNull);
  });
}
