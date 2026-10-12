import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'guild_identity_fixture.dart';

class GuildQaTls extends HttpOverrides {
  GuildQaTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4840 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('configured guild identity native owned API acceptance', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4840/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA config required');
    }
    HttpOverrides.global = GuildQaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final session = FixtureSession(origin);
    addTearDown(session.close);
    await tester.runAsync(() => session.login('qa_admin', password));
    await tester.runAsync(
      () => session.json(
        'POST',
        '/auth/register',
        body: {'login': 'qa_identity_member', 'password': password},
        status: 201,
      ),
    );
    Future<void> rename(String name) async {
      final current = await session.json('GET', '/admin/guild-settings');
      await session.json(
        'PATCH',
        '/admin/guild-settings',
        body: {
          'name': name,
          'welcome_channel_id': null,
          'expected_revision': current['revision'],
        },
      );
    }

    final longName = List.filled(20, 'Ж🌍界é').join();
    await tester.runAsync(() => rename(longName));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', origin);
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    await tester.pumpWidget(BoohtacordApp(state: state));
    await tester.runAsync(state.initialize);
    Future<void> waitFor(bool Function() test) async {
      for (var i = 0; i < 120 && !test(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      expect(test(), true);
    }

    await waitFor(() => state.guildProfile.name == longName);
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    expect(find.text(longName), findsWidgets);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('guild-auth-long-unicode');
    Future<void> login([String name = 'qa_admin']) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), name);
      await tester.enterText(fields.at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('Войти').last);
      await waitFor(() => state.phase == AppPhase.ready);
      await tester.pumpAndSettle();
    }

    await login();
    final logos = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label?.startsWith('Логотип гильдии') ?? false),
    );
    expect(logos, findsOneWidget);
    expect(
      tester.widget<Semantics>(logos).properties.label,
      'Логотип гильдии $longName',
    );
    expect(
      tester.getSemantics(logos).getSemanticsData().label,
      'Логотип гильдии $longName',
    );
    expect(find.text('Сменить сервер'), findsNothing);
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('guild-header-long-unicode');
    const renamed = 'Гильдия обновлена 🌍界';
    await tester.runAsync(() => rename(renamed));
    await waitFor(() => state.guildProfile.name == renamed);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Semantics>(logos).properties.label,
      'Логотип гильдии $renamed',
    );
    expect(find.text(renamed), findsWidgets);
    await binding.takeScreenshot('guild-renamed-realtime');
    await tester.runAsync(state.logout);
    await waitFor(
      () =>
          state.phase == AppPhase.signedOut &&
          state.guildProfile.name == renamed,
    );
    await tester.pumpAndSettle();
    expect(find.text(renamed), findsWidgets);
    await binding.takeScreenshot('guild-signed-out-renamed');
    await login();
    expect(state.guildProfile.name, renamed);
    await binding.takeScreenshot('guild-new-sign-in');
    await tester.runAsync(state.logout);
    await waitFor(() => state.phase == AppPhase.signedOut);
    await tester.pumpAndSettle();
    await login('qa_identity_member');
    expect(state.guildProfile.name, renamed);
    expect(state.user?.role, 'MEMBER');
    await binding.takeScreenshot('guild-account-switch');
    await tester.runAsync(state.logout);
    semantics.dispose();
    binding.reportData = {
      ...?binding.reportData,
      'guild_identity_qa': {
        'status': 'PASS',
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'physical_device': false,
        'checks': {
          'long_unicode_auth_and_header_layout': 'PASS',
          'full_logo_semantics_once': 'PASS',
          'no_server_switcher': 'PASS',
          'second_admin_session_rename_realtime': 'PASS',
          'logout_and_new_sign_in': 'PASS',
          'admin_to_member_account_switch': 'PASS',
        },
        'semantics_excerpt': {
          'configured_name': 'synthetic 80 Unicode code points',
          'logo_label_before': 'Логотип гильдии [80-codepoint synthetic name]',
          'logo_label_after': 'Логотип гильдии Гильдия обновлена 🌍界',
          'logo_nodes': 1,
        },
        'reader': 'NOT_RUN: actual assistive technology speech not checked; native semantics tree alone is insufficient',
        'notifications': 'NOT_RUN',
        'account_switch': 'PASS',
      },
    };
  });
}
