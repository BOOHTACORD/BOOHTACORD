import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'issue689_support.dart' show waitFor;
import 'local_qa_test.dart' show QaTls;

class DelayedSessionApi extends ApiClient {
  final release = Completer<void>();
  bool held = false, released = false;
  String? savedAccount;
  @override
  Future<SessionUser?> currentSession() async {
    final result = await super.currentSession();
    if (!held) {
      held = true;
      savedAccount = result?.accountId;
      await release.future;
      released = true;
    }
    return result;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'expired startup offers retry and restores the real saved session',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      if (origin != 'https://localhost:4810/api/v1' ||
          pin.length != 64 ||
          password.isEmpty) {
        throw StateError(
          'Owned loopback API and disposable credentials required',
        );
      }
      HttpOverrides.global = QaTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      if (Platform.isWindows) {
        SharedPreferences.setMockInitialValues({});
        FlutterSecureStorage.setMockInitialValues({});
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', origin);
      final api = DelayedSessionApi();
      await tester.runAsync(() async {
        await api.initialize();
        await api.authenticate('qa_admin', password, register: false);
      });
      final app = AppState(
        api,
        startupSessionTimeout: const Duration(seconds: 10),
      );
      addTearDown(app.dispose);
      await tester.pumpWidget(BoohtacordApp(state: app));
      await tester.runAsync(app.initialize);
      await tester.pumpAndSettle();
      expect(
        api.held,
        isTrue,
        reason: 'the real session response must be held',
      );
      expect(app.phase, AppPhase.connectionError);
      expect(app.user, isNull);
      expect(find.text('Повторить подключение'), findsOneWidget);
      expect(find.text('Войти'), findsNothing);
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('startup-timeout');
      }
      api.release.complete();
      await waitFor(tester, () => api.released);
      await tester.pumpAndSettle();
      expect(app.user, isNull);
      expect(app.phase, AppPhase.connectionError);
      await tester.tap(find.text('Повторить подключение'));
      await waitFor(tester, () => app.phase == AppPhase.ready);
      expect(app.user, isNotNull);
      expect(app.user?.accountId, api.savedAccount);
      await tester.pumpAndSettle();
      expect(app.phase, AppPhase.ready);
      await waitFor(
        tester,
        () => app.realtime.connected && app.maintenanceKnown,
      );
      await tester.pumpAndSettle();
      expect(find.text('Повторить подключение'), findsNothing);
      if (Platform.isAndroid) {
        await binding.takeScreenshot('startup-recovered');
      }
      await tester.runAsync(app.logout);
      await waitFor(tester, () => app.phase == AppPhase.signedOut);
      await tester.pumpAndSettle();
      expect(find.text('Войти'), findsWidgets);
      expect(tester.takeException(), isNull);
      if (Platform.isAndroid) {
        await binding.takeScreenshot('startup-signed-out');
      }
    },
  );
}
