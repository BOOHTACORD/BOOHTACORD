import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'profile_revision/fixture.dart';

class MobileNavigationTls extends HttpOverrides {
  MobileNavigationTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4840 &&
            sha256.convert(cert.der).toString() == pin;
}

class MobileObservedClient extends http.BaseClient {
  final delegate = http.Client();
  int voiceAdmissionMutations = 0,
      voiceTelemetryReports = 0,
      searchResponses = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.method != 'GET') {
      final path = request.url.path;
      if (RegExp(r'/voice/channels/[^/]+/leases$').hasMatch(path) ||
          RegExp(r'/voice/leases/[^/]+(?:/credential)?$').hasMatch(path)) {
        voiceAdmissionMutations++;
      } else if (path.endsWith('/voice/screen-metrics')) {
        voiceTelemetryReports++;
      }
    }
    return delegate.send(request).then((response) {
      if (request.url.path.endsWith('/search/messages')) searchResponses++;
      return response;
    });
  }

  @override
  void close() => delegate.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual native mobile navigation preserves LiveKit listener call', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4840/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA inputs required');
    }
    HttpOverrides.global = MobileNavigationTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final admin = FixtureSession(origin), peer = FixtureSession(origin);
    final observed = MobileObservedClient(),
        state = AppState(ApiClient(client: observed));
    final peerRoom = lk.Room();
    addTearDown(() {
      state.dispose();
      observed.close();
      admin.close();
      peer.close();
      peerRoom.dispose();
    });
    final report = <String, Object?>{
      'issue': 292,
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'physical_device': false,
      'mocks': false,
      'build_mode': 'debug',
      'viewport': {
        'physical_width': tester.view.physicalSize.width,
        'physical_height': tester.view.physicalSize.height,
        'device_pixel_ratio': tester.view.devicePixelRatio,
      },
      'roles': ['ADMIN', 'MEMBER'],
      'voice_scope': 'Two actual LiveKit listeners; real RTC transport stats, microphone/audio quality not exercised. Data publishing remains forbidden by the server contract.',
      'checks': <String, String>{},
      'observations': <String, Object?>{},
      'physical_OS_gesture': 'NOT_RUN',
      'spoken_screen_reader': 'NOT_RUN',
    };
    final checks = report['checks'] as Map<String, String>,
        observations = report['observations'] as Map<String, Object?>;
    binding.reportData = {
      ...?binding.reportData,
      'mobile_navigation_qa': report,
    };
    var phase = 'fixtures';
    Future<T> real<T>(Future<T> Function() action) async =>
        (await tester.runAsync<T>(action)) as T;
    Future<void> waitFor(bool Function() value, String label) async {
      for (var i = 0; i < 300 && !value(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (!value()) {
        report['failed_wait'] = label;
        report['voice_phase'] = state.voicePhase.name;
        report['room_state'] = state.room?.connectionState.name;
        report['peer_room_state'] = peerRoom.connectionState.name;
        report['user_error_present'] = state.error != null;
      }
      expect(value(), true, reason: label);
    }

    Future<void> settle() async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await settle();
      await binding.takeScreenshot(name);
    }

    Future<void> closeNav() async {
      final f = find.byTooltip('Закрыть навигацию').hitTestable();
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f);
        await settle();
      }
    }

    Future<void> nav() async {
      await closeNav();
      await tester.tap(find.byTooltip('Открыть навигацию').hitTestable().first);
      await settle();
    }

    Future<void> back() async {
      if (Platform.isAndroid) {
        final response = await real(
          () => http.post(
            Uri.parse(
              '${const String.fromEnvironment('QA_CONTROL_BASE')}/android-back',
            ),
            headers: {
              'X-QA-Control': const String.fromEnvironment('QA_CONTROL_KEY'),
            },
          ),
        );
        expect(response.statusCode, 204);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
      } else {
        await tester.binding.handlePopRoute();
      }
      await settle();
    }

    Finder composer() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Написать сообщение…',
    );
    String draft() => tester.widget<TextField>(composer()).controller!.text;
    Future<void> choosePanel(String label) async {
      await nav();
      await tester.tap(find.byTooltip('Настройки аккаунта'));
      await settle();
      await tester.tap(find.text(label).last);
      await settle();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
    }

    try {
      await real(() => admin.login('qa_admin', password));
      final member = await real(
        () => admin.json(
          'POST',
          '/auth/register',
          body: {'login': 'qa_mobile_peer', 'password': password},
          status: 201,
        ),
      );
      await real(() => peer.login('qa_mobile_peer', password));
      await real(() => peer.rename('Тестовый собеседник'));
      final category = await real(
        () => admin.json(
          'POST',
          '/admin/categories',
          body: {'name': 'QaMobile'},
          status: 201,
        ),
      );
      final channels = <String, Map<String, dynamic>>{};
      for (final row in [
        ('QaMobileText', 'TEXT'),
        ('QaMobileOther', 'TEXT'),
        ('QaMobileVoice', 'VOICE'),
      ]) {
        channels[row.$1] = await real(
          () => admin.json(
            'POST',
            '/admin/categories/${category['id']}/channels',
            body: {'name': row.$1, 'kind': row.$2},
            status: 201,
          ),
        );
      }
      await real(
        () => admin.json(
          'POST',
          '/direct-messages',
          body: {'participant_id': member['id']},
          status: 201,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', origin);
      await tester.pumpWidget(BoohtacordApp(state: state));
      await real(state.initialize);
      await settle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await settle();
      }
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'qa_admin');
      await tester.enterText(fields.at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('Войти').last);
      await waitFor(
        () => state.phase == AppPhase.ready && state.topology != null,
        'authenticated real topology',
      );
      await settle();
      await closeNav();
      Future<void> selectChannel(String label) async {
        await nav();
        if (state.navigationSection != NavigationSection.channels) {
          await tester.tap(find.text('Каналы').last);
          await settle();
        }
        final row = find.byKey(
          ValueKey('workspace-channel-row:${channels[label]!['id']}'),
        );
        await tester.ensureVisible(row);
        await tester.tap(row);
        await waitFor(
          () => state.selectedChannel?.id == channels[label]!['id'],
          'selected authorized channel',
        );
        await settle();
        expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
      }

      phase = 'actual two participant LiveKit listener call';
      // Prepare the real prejoin surface without the drawer's intentional auto-join.
      final voice = state.topology!.categories
          .expand((c) => c.channels)
          .firstWhere((c) => c.id == channels['QaMobileVoice']!['id']);
      await real(() => state.selectChannel(voice));
      await settle();
      final lease = await real(
        () => peer.json(
          'POST',
          '/voice/channels/${channels['QaMobileVoice']!['id']}/leases',
          body: {'transfer': false},
          status: 201,
        ),
      );
      final credential = await real(
        () => peer.json('POST', '/voice/leases/${lease['id']}/credential'),
      );
      await real(
        () => peerRoom.connect(
          credential['url'] as String,
          credential['token'] as String,
          connectOptions: const lk.ConnectOptions(autoSubscribe: false),
        ),
      );
      await tester.tap(find.text('Подключиться без микрофона').last);
      await waitFor(
        () =>
            state.room?.connectionState == lk.ConnectionState.connected &&
            state.voicePhase == VoicePhase.listener,
        'native actual SFU connected',
      );
      await settle();
      await waitFor(
        () =>
            state.room!.remoteParticipants.isNotEmpty &&
            peerRoom.remoteParticipants.isNotEmpty,
        'two SFU participants mutually visible',
      );
      phase = 'actual connected RTC transport stats';
      Future<Map<String, int>> transportProof(lk.Room room) async {
        final groups = await real(room.getPeerConnectionStats);
        final stats = groups.expand((group) => group).toList();
        return {
          'succeeded_candidate_pairs': stats
              .where(
                (entry) =>
                    entry.type == 'candidate-pair' &&
                    entry.values['state'] == 'succeeded',
              )
              .length,
          'connected_dtls_transports': stats
              .where(
                (entry) =>
                    entry.type == 'transport' &&
                    entry.values['dtlsState'] == 'connected',
              )
              .length,
        };
      }

      final nativeTransport = await transportProof(state.room!),
          peerTransport = await transportProof(peerRoom);
      report['native_RTC_transport'] = nativeTransport;
      report['peer_RTC_transport'] = peerTransport;
      expect(nativeTransport['succeeded_candidate_pairs'], greaterThan(0));
      expect(peerTransport['succeeded_candidate_pairs'], greaterThan(0));
      final connectedRoom = state.room!,
          admittedLease = state.voice.leaseId!,
          voiceChannel = state.voiceChannel!;
      final admittedMutations = observed.voiceAdmissionMutations;
      void retained() {
        expect(state.room, same(connectedRoom));
        expect(state.room!.connectionState, lk.ConnectionState.connected);
        expect(state.voice.leaseId, admittedLease);
        expect(state.voiceChannel, voiceChannel);
        expect(observed.voiceAdmissionMutations, admittedMutations);
        expect(state.microphoneMuted, true);
      }

      checks['actual_two_listener_SFU_and_RTC_transport'] = 'PASS';
      await capture('native-connected-voice');
      phase = 'drawer selection and relevant context while connected';
      await selectChannel('QaMobileText');
      retained();
      expect(find.text('QaMobileText').hitTestable(), findsWidgets);
      await capture('native-connected-text-context');
      checks['drawer_channel_selection_closes_context_and_voice_retained'] =
          'PASS';
      phase = 'drawer close outside Escape OS Back and focus';
      await tester.tap(composer());
      await tester.pump();
      final returnFocus = FocusManager.instance.primaryFocus;
      expect(returnFocus, isNotNull);
      await nav();
      await capture('native-navigation-overlay');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
      expect(FocusManager.instance.primaryFocus, same(returnFocus));
      retained();
      await nav();
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(width - 8, 320));
      await settle();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
      retained();
      await nav();
      await back();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
      expect(FocusManager.instance.primaryFocus, same(returnFocus));
      retained();
      checks['drawer_outside_Escape_Back_focus_and_voice_retained'] = 'PASS';
      report['Back_input'] = Platform.isAndroid
          ? 'ADB KEYCODE_BACK through emulator OS dispatch'
          : 'integration binding handlePopRoute; OS route swipe not exercised';
      phase = 'edge swipe native widgets';
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.dragFrom(const Offset(1, 220), const Offset(150, 0));
      await settle();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsOneWidget);
      await tester.dragFrom(const Offset(190, 220), const Offset(-150, 0));
      await settle();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
      retained();
      await tester.dragFrom(Offset(width - 1, 220), const Offset(-150, 0));
      await settle();
      expect(
        find.byTooltip('Закрыть участников').hitTestable(),
        findsOneWidget,
      );
      await capture('native-members-overlay');
      await back();
      expect(find.byTooltip('Закрыть участников').hitTestable(), findsNothing);
      retained();
      checks['controlled_edge_swipes_both_drawers_and_Back'] = 'PASS';
      phase = 'actual DM drawer selection and draft';
      await nav();
      await tester.tap(find.text('Личные').last);
      await settle();
      expect(state.navigationSection, NavigationSection.directMessages);
      await tester.tap(find.text('Тестовый собеседник').hitTestable().first);
      await waitFor(
        () => state.selectedDirectMessage?.participantId == member['id'],
        'authorized selected DM',
      );
      await settle();
      expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
      retained();
      await capture('native-connected-dm-context');
      await tester.enterText(composer(), 'QA_LOCAL_UNSENT');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      checks['drawer_DM_selection_closes_relevant_context_and_voice_retained'] =
          'PASS';
      phase = 'profile settings and one platform Back preserves DM draft';
      await choosePanel('Профиль');
      expect(state.workspacePanel, WorkspacePanel.profile);
      retained();
      await capture('native-connected-profile');
      final profileChecks = <String, String>{};
      report['profile297_checks'] = profileChecks;
      final displayName = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Отображаемое имя',
      );
      final savedName = state.profile!.displayName;
      await tester.ensureVisible(displayName);
      await settle();
      expect(displayName.hitTestable(), findsOneWidget);
      await tester.enterText(displayName, 'Тестовый профиль навигации');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
      await back();
      expect(find.text('Несохранённые изменения'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await settle();
      expect(state.workspacePanel, WorkspacePanel.profile);
      expect(
        tester.widget<TextField>(displayName).controller!.text,
        'Тестовый профиль навигации',
      );
      retained();
      profileChecks['dirty_platform_Back_cancel_retains_editor_and_voice'] =
          'PASS';
      final security = find.text('Безопасность');
      await tester.ensureVisible(security);
      await settle();
      expect(security.hitTestable(), findsOneWidget);
      await tester.tap(security);
      await settle();
      final logout = find.text('Выйти из аккаунта');
      await tester.ensureVisible(logout);
      await settle();
      expect(logout.hitTestable(), findsOneWidget);
      await tester.tap(logout);
      await settle();
      expect(find.text('Несохранённые изменения'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await settle();
      retained();
      expect(state.phase, AppPhase.ready);
      final profileTab = find.text('Профиль');
      await tester.ensureVisible(profileTab);
      await settle();
      expect(profileTab.hitTestable(), findsOneWidget);
      await tester.tap(profileTab);
      await settle();
      expect(
        tester.widget<TextField>(displayName).controller!.text,
        'Тестовый профиль навигации',
      );
      profileChecks['dirty_logout_cancel_retains_editor_and_voice'] = 'PASS';
      await tester.enterText(displayName, savedName);
      await settle();
      expect(find.text('Изменения не внесены'), findsOneWidget);
      await tester.enterText(displayName, 'Тестовый профиль навигации');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      final save = find.text('Сохранить профиль');
      await tester.ensureVisible(save);
      await settle();
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await waitFor(
        () =>
            state.profile?.displayName == 'Тестовый профиль навигации' &&
            !state.profileSaving,
        'actual native profile save',
      );
      await settle();
      expect(find.text('Имя профиля сохранено.'), findsWidgets);
      retained();
      await capture('native-profile-save-feedback');
      profileChecks['actual_profile_save_feedback'] = 'PASS';
      for (final tab in ['Уведомления', 'О приложении', 'Безопасность']) {
        final target = find.text(tab);
        await tester.ensureVisible(target);
        await settle();
        expect(target.hitTestable(), findsOneWidget);
        await tester.tap(target);
        await settle();
        retained();
      }
      await tester.ensureVisible(logout);
      await settle();
      expect(logout.hitTestable(), findsOneWidget);
      await tester.tap(logout);
      await settle();
      expect(find.text('Подтвердите выход из аккаунта'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await settle();
      retained();
      expect(state.phase, AppPhase.ready);
      profileChecks['four_profile_tabs_and_logout_confirmation_cancel'] =
          'PASS';
      await back();
      expect(state.workspacePanel, WorkspacePanel.none);
      await closeNav();
      expect(state.selectedDirectMessage?.participantId, member['id']);
      expect(draft(), 'QA_LOCAL_UNSENT');
      retained();
      checks['profile_one_Back_restores_DM_draft_and_voice'] = 'PASS';
      phase = 'audio settings and one Back';
      await choosePanel('Настройки аудио');
      expect(state.workspacePanel, WorkspacePanel.audio);
      retained();
      await back();
      expect(state.workspacePanel, WorkspacePanel.none);
      await closeNav();
      expect(draft(), 'QA_LOCAL_UNSENT');
      retained();
      checks['audio_one_Back_restores_DM_draft_and_voice'] = 'PASS';
      phase = 'administration filter and one Back';
      await choosePanel('Администрирование');
      expect(state.workspacePanel, WorkspacePanel.admin);
      await waitFor(
        () => find
            .byKey(const ValueKey('admin-member-search'))
            .evaluate()
            .isNotEmpty,
        'real admin account list',
      );
      await settle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-member-search')),
        'qa_mobile_peer',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      retained();
      await capture('native-connected-admin-filter');
      await back();
      expect(state.workspacePanel, WorkspacePanel.none);
      await closeNav();
      expect(draft(), 'QA_LOCAL_UNSENT');
      retained();
      checks['admin_one_Back_restores_DM_draft_and_voice'] = 'PASS';
      await choosePanel('Администрирование');
      await waitFor(
        () => find
            .byKey(const ValueKey('admin-member-search'))
            .evaluate()
            .isNotEmpty,
        'admin reopen',
      );
      await settle();
      observations['admin_filter_after_panel_unmount'] =
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('admin-member-search')),
              )
              .controller!
              .text
              .isEmpty
          ? 'reset to empty'
          : 'retained';
      await back();
      await closeNav();
      phase = 'DM search query scope owned session Back/reopen';
      await nav();
      await tester.tap(find.byTooltip('Поиск сообщений').hitTestable().first);
      await settle();
      expect(state.workspacePanel, WorkspacePanel.search);
      final search = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Поиск сообщений',
      );
      final beforeSearch = observed.searchResponses;
      await tester.enterText(search, 'qa_nomatch');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await waitFor(
        () =>
            observed.searchResponses > beforeSearch &&
            tester.widget<TextField>(search).enabled == true,
        'actual empty search complete',
      );
      await settle();
      retained();
      await capture('native-connected-search');
      await back();
      expect(state.workspacePanel, WorkspacePanel.none);
      await closeNav();
      expect(draft(), 'QA_LOCAL_UNSENT');
      retained();
      await nav();
      await tester.tap(find.byTooltip('Поиск сообщений').hitTestable().first);
      await settle();
      expect(tester.widget<TextField>(search).controller!.text, 'qa_nomatch');
      await back();
      await closeNav();
      checks['DM_search_owned_query_reopen_draft_and_voice'] = 'PASS';
      observations['drawer_tab_after_return'] =
          state.navigationSection == NavigationSection.directMessages
          ? 'DM retained'
          : 'channels reset';
      phase = 'logout clears voice lease scope and stale workspace';
      await real(state.logout);
      await settle();
      expect(state.phase, AppPhase.signedOut);
      expect(state.room, isNull);
      expect(state.voice.leaseId, isNull);
      expect(state.selectedDirectMessage, isNull);
      await capture('native-logout-cleared');
      checks['logout_clears_voice_and_selected_context'] = 'PASS';
      report['voice_telemetry_reports'] = observed.voiceTelemetryReports;
      await real(peerRoom.disconnect);
      await real(
        () => peer.json('DELETE', '/voice/leases/${lease['id']}', status: 204),
      );
      report['status'] = 'PARTIAL';
    } catch (error, stack) {
      report.addAll({
        'status': 'FAIL',
        'failed_phase': phase,
        'error_type': error.runtimeType.toString(),
        'failed_test_line': int.tryParse(
          RegExp(r'mobile_navigation_qa_test.dart:(\d+):')
                  .firstMatch(stack.toString())
                  ?.group(1) ??
              '',
        ),
      });
      binding.reportData = {
        ...?binding.reportData,
        'mobile_navigation_qa': report,
      };
      rethrow;
    }
    binding.reportData = {
      ...?binding.reportData,
      'mobile_navigation_qa': report,
    };
  });
}
