import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/controller.dart';

class RosterTls extends HttpOverrides {
  RosterTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 5070 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual populated roster fault recovery and native lifecycle', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD'),
        controlSecret = String.fromEnvironment('QA_CONTROL');
    if (origin != 'https://localhost:5070/api/v1' ||
        pin.length != 64 ||
        password.isEmpty ||
        controlSecret.isEmpty) {
      throw StateError('Owned QA config required');
    }
    const supplemental = bool.fromEnvironment('QA_BACKGROUND_ONLY');
    HttpOverrides.global = RosterTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', origin);
    final api = ApiClient(), state = AppState(api);
    api.baseUrl = origin;
    await api.transport.session.clearCookie();
    final report = <String, dynamic>{
      'issue': 272,
      'status': 'RUNNING',
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'physical_device': false,
      'actual_api': true,
      'actual_sfu': true,
      'mocks': false,
      'checks': <String, String>{},
      'counts': <Map<String, dynamic>>[],
      'prejoin_route': 'Controlled production state.selectChannel of actual ACL-loaded RosterVoice. Not native pointer channel-row navigation (which autojoins).',
    };
    final checks = report['checks'] as Map<String, String>;
    String phase = 'startup';
    binding.reportData = {...?binding.reportData, 'roster_qa': report};
    var converted = false;
    void mark(String value) {
      phase = value;
      debugPrint('QA272_PHASE: $value');
    }

    Future<void> settle() async {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(tester.takeException(), isNull);
    }

    Future<void> wait(bool Function() predicate) async {
      for (var i = 0; i < 200 && !predicate(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(predicate(), true, reason: phase);
      expect(tester.takeException(), isNull);
    }

    Future<void> action(String name) async {
      await tester.runAsync(() async {
        final c = HttpClient();
        try {
          await (() async {
            final req = await c.postUrl(
              Uri.parse('http://localhost:5076/roster'),
            );
            req.headers.set('X-QA-Control', controlSecret);
            req.headers.contentType = ContentType.json;
            final body = jsonEncode({'action': name});
            req.contentLength = utf8.encode(body).length;
            req.write(body);
            final r = await req.close();
            expect(r.statusCode, 200);
            final data = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
            expect(data['action'], name);
            expect(data['actual_control'], true);
          })().timeout(const Duration(seconds: 50));
        } finally {
          c.close(force: true);
        }
      });
    }

    Future<void> recoverPublishers() async {
      await action('sfu_start');
      final available = await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(deadline)) {
          try {
            await api.voiceParticipants();
            return true;
          } on ApiFailure catch (e) {
            if (e.status != 503) rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return false;
      });
      expect(
        available,
        true,
        reason: 'Actual SFU-backed API ready before publisher join',
      );
      await action('publishers_rejoin');
    }

    Future<void> capture(String name) async {
      await settle();
      if (Platform.isAndroid && !converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      final future = binding.takeScreenshot(name);
      var done = false;
      future.whenComplete(() => done = true);
      for (var i = 0; i < 60 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }
      await future.timeout(const Duration(seconds: 15));
    }

    int count() =>
        state.voiceRosters
            ?.where((r) => r.channelId == state.selectedChannel?.id)
            .firstOrNull
            ?.participants
            .length ??
        -1;
    Future<void> fresh(int n) async {
      await wait(
        () => state.voiceRoster.phase == VoiceRosterPhase.fresh && count() == n,
      );
      (report['counts'] as List).add({
        'scenario': phase,
        'count': n,
        'fresh': true,
      });
    }

    Future<void> closeNavigation() async {
      await settle();
      final close = find.byTooltip('Закрыть навигацию').hitTestable();
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first);
        await settle();
      }
    }

    Future<void> retry() async {
      final button = find
          .byKey(const ValueKey('retry-voice-roster'))
          .hitTestable();
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button.first);
        await settle();
      }
    }

    try {
      mark('initial SFU unavailable');
      if (!supplemental) await action('sfu_stop');
      await tester.runAsync(state.initialize);
      await tester.pumpWidget(BoohtacordApp(state: state));
      await settle();
      await tester.enterText(
        find.byType(TextField).at(0),
        'qa_roster_${Platform.operatingSystem}',
      );
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await wait(() => state.phase == AppPhase.ready && state.topology != null);
      final voice = state.topology!.categories
          .expand((c) => c.channels)
          .singleWhere((c) => c.name == 'RosterVoice');
      await tester.runAsync(() => state.selectChannel(voice));
      await closeNavigation();
      if (supplemental) {
        report['scope'] = 'Supplemental actual OS framebuffer at background and listener phases; Android4 full functional receipt preserved';
        await fresh(2);
        await capture('native-before-background');
        mark('supplemental actual Android background');
        await action('android_background_resume');
        await fresh(2);
        await capture('native-after-background-binding');
        await action('android_framebuffer_background');
        checks['background_foreground'] = 'PASS';
        mark('supplemental actual listener');
        final listen = find.widgetWithText(
          OutlinedButton,
          'Подключиться без микрофона',
        );
        await tester.ensureVisible(listen);
        await tester.tap(listen);
        await wait(() => state.voicePhase == VoicePhase.listener);
        await capture('native-listener-binding');
        await action('android_framebuffer_listener');
        checks['listener_framebuffer'] = 'PASS';
        await tester.tap(
          find.byTooltip('Выйти из голосового канала').hitTestable().first,
        );
        await wait(
          () => state.voicePhase == VoicePhase.idle && state.room == null,
        );
        await tester.runAsync(state.logout);
        await settle();
        expect(state.voiceRoster.watching, false);
        checks['cleanup'] = 'PASS';
        report['status'] = 'PASS';
        mark('complete');
        return;
      }
      await wait(() => state.voiceRoster.phase == VoiceRosterPhase.unavailable);
      expect(find.text('Пока никого нет.'), findsNothing);
      expect(
        find.textContaining('Не удалось обновить состав комнаты'),
        findsWidgets,
      );
      final failureStatus = await tester.runAsync(() async {
        try {
          await api.voiceParticipants();
          return 200;
        } on ApiFailure catch (error) {
          return error.status;
        }
      });
      expect(failureStatus, 503);
      await capture('native-initial-503');
      checks['initial_503_no_false_zero'] = 'PASS';
      mark('recovery two actual peer accounts');
      await recoverPublishers();
      await retry();
      await fresh(2);
      final rest = (await tester.runAsync(api.voiceParticipants))!;
      expect(
        rest.singleWhere((r) => r.channelId == voice.id).participants.length,
        2,
      );
      await settle();
      expect(find.text('Сейчас в канале: 2'), findsWidgets);
      await capture('native-populated-two');
      checks['populated_rest_sse_two_accounts'] = 'PASS';
      mark('peer leave and rejoin');
      await action('peer_leave');
      await fresh(1);
      await capture('native-peer-left');
      await action('peer_join');
      await fresh(2);
      checks['realtime_join_leave'] = 'PASS';
      mark('refresh SFU unavailable');
      await action('sfu_stop');
      await wait(
        () =>
            state.voiceRoster.phase == VoiceRosterPhase.stale ||
            state.voiceRoster.phase == VoiceRosterPhase.unavailable,
      );
      expect(find.text('Пока никого нет.'), findsNothing);
      expect(
        find.textContaining('Не удалось обновить состав комнаты'),
        findsWidgets,
      );
      await capture('native-refresh-unavailable');
      await recoverPublishers();
      await retry();
      await fresh(2);
      await capture('native-recovered-populated');
      checks['refresh_fault_recovery_no_false_zero'] = 'PASS';
      if (Platform.isAndroid) {
        mark('actual Android background foreground');
        await action('android_background_resume');
        await fresh(2);
        await capture('native-after-background');
        checks['background_foreground'] = 'PASS';
        mark('actual Android listener rejoin');
        final listen = find
            .widgetWithText(OutlinedButton, 'Подключиться без микрофона')
            .hitTestable();
        await tester.ensureVisible(listen);
        await tester.tap(listen);
        await wait(() => state.voicePhase == VoicePhase.listener);
        expect(state.room, isNotNull);
        await capture('native-listener-connected');
        await tester.tap(
          find.byTooltip('Выйти из голосового канала').hitTestable().first,
        );
        await wait(
          () => state.voicePhase == VoicePhase.idle && state.room == null,
        );
        await fresh(2);
        await tester.ensureVisible(
          find.widgetWithText(OutlinedButton, 'Подключиться без микрофона'),
        );
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Подключиться без микрофона'),
        );
        await wait(() => state.voicePhase == VoicePhase.listener);
        await tester.tap(
          find.byTooltip('Выйти из голосового канала').hitTestable().first,
        );
        await wait(
          () => state.voicePhase == VoicePhase.idle && state.room == null,
        );
        await fresh(2);
        checks['listener_rejoin_cleanup'] = 'PASS';
      } else {
        checks['background_foreground'] = 'NOT_RUN';
        checks['listener_rejoin_cleanup'] = 'NOT_RUN';
        report['ios_limit'] = 'Nonmedia roster only. Prior same-simulator iOS27 AURemoteIO abort after voice join; no blind media retry. Actual OS background not exercised.';
      }
      mark('member ACL and logout clears roster');
      final denied = await tester.runAsync(() async {
        try {
          await api.loadRolePolicies();
          return 200;
        } on ApiFailure catch (error) {
          return error.status;
        }
      });
      expect(denied, 403);
      await tester.runAsync(state.logout);
      await settle();
      expect(state.user, isNull);
      expect(state.voiceRosters, isNull);
      expect(state.voiceRoster.watching, false);
      expect(find.text('Сейчас в канале: 2'), findsNothing);
      await capture('native-logout-cleared');
      checks['logout_clears_roster'] = 'PASS';
      final guestStatus = await tester.runAsync(() async {
        try {
          await api.voiceParticipants();
          return 200;
        } on ApiFailure catch (error) {
          return error.status;
        }
      });
      expect(
        guestStatus,
        isNull,
        reason: 'Production closed session scope rejects before protected transport',
      );
      report['logged_out_client_guard'] =
          'PASS: closed scope rejects protected request before transport';
      final anonymousStatus = await tester.runAsync(() async {
        final client = HttpClient();
        try {
          return await (() async {
            final request = await client.getUrl(
              Uri.parse('$origin/voice/participants'),
            );
            request.headers.set('Origin', 'https://localhost:5070');
            final response = await request.close();
            await response.drain<void>();
            return response.statusCode;
          })().timeout(const Duration(seconds: 15));
        } finally {
          client.close(force: true);
        }
      });
      expect(anonymousStatus, 401);
      report['guest_acl_method'] = 'Separate real anonymous HTTPS request after production client scope rejects logged-out protected call';
      checks['guest_member_acl'] = 'PASS';
      await tester.enterText(
        find.byType(TextField).at(0),
        'qa_roster_${Platform.operatingSystem}',
      );
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await wait(() => state.phase == AppPhase.ready && state.topology != null);
      await tester.runAsync(
        () => state.selectChannel(
          state.topology!.categories
              .expand((c) => c.channels)
              .singleWhere((c) => c.name == 'RosterVoice'),
        ),
      );
      await closeNavigation();
      await fresh(2);
      checks['login_after_logout_fresh_scope'] = 'PASS';
      await tester.runAsync(state.logout);
      await settle();
      report['status'] = checks.values.contains('NOT_RUN') ? 'PARTIAL' : 'PASS';
      mark('complete');
    } catch (e) {
      report['status'] = 'FAIL';
      report['failed_at'] = phase;
      report['error_type'] = e.runtimeType.toString();
      try {
        await capture('native-failure');
      } catch (_) {}
      rethrow;
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      api.transport.client.close();
      await tester.pump();
      report['owned_test_handles_closed'] = true;
      binding.reportData = {...?binding.reportData, 'roster_qa': report};
    }
  });
}
