import 'dart:io';
import 'dart:async';

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

class AdminDialogsTls extends HttpOverrides {
  AdminDialogsTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4950 &&
            sha256.convert(cert.der).toString() == pin;
}

class AdminObservedClient extends http.BaseClient {
  final delegate = http.Client();
  int voiceAdmissionMutations = 0,
      voiceTelemetryReports = 0,
      searchResponses = 0;
  Completer<void>? createResponseHold;
  int categoryCreates = 0;
  final roleSaveStatuses = <int>[];
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
    final categoryCreate =
        request.method == 'POST' && request.url.path.endsWith('/categories');
    if (categoryCreate) categoryCreates++;
    return delegate.send(request).then((response) async {
      if (request.method == 'PUT' &&
          request.url.path.endsWith('/admin/roles/MEMBER/permissions'))
        roleSaveStatuses.add(response.statusCode);
      if (categoryCreate && createResponseHold != null)
        await createResponseHold!.future;
      if (request.url.path.endsWith('/search/messages')) searchResponses++;
      return response;
    });
  }

  @override
  void close() => delegate.close();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual native administration and dialogs preserve a real LiveKit listener call',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE'),
          pin = String.fromEnvironment('QA_CERT_SHA256'),
          password = String.fromEnvironment('QA_PASSWORD');
      if (origin != 'https://localhost:4950/api/v1' ||
          pin.length != 64 ||
          password.isEmpty) {
        throw StateError('Owned QA inputs required');
      }
      HttpOverrides.global = AdminDialogsTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      final admin = FixtureSession(origin), peer = FixtureSession(origin);
      final observed = AdminObservedClient(),
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
        'issues': [295, 298],
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
        'roles': ['ADMINISTRATOR', 'MEMBER'],
        'voice_scope': 'Two actual LiveKit listeners; real RTC transport stats, microphone/audio quality not exercised. Data publishing remains forbidden by the server contract.',
        'checks': <String, String>{},
        'observations': <String, Object?>{},
        'physical_OS_gesture': 'NOT_RUN',
        'spoken_screen_reader': 'NOT_RUN',
      };
      final checks = report['checks'] as Map<String, String>,
          observations = report['observations'] as Map<String, Object?>;
      binding.reportData = {...?binding.reportData, 'admin_dialogs_qa': report};
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
        await tester.tap(
          find.byTooltip('Открыть навигацию').hitTestable().first,
        );
        await settle();
      }

      Future<void> back() async {
        await tester.binding.handlePopRoute();
        await settle();
      }

      Finder composer() => find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.hintText == 'Написать сообщение…',
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
            body: {'login': 'qa_admin_dialogs_peer', 'password': password},
            status: 201,
          ),
        );
        await real(() => peer.login('qa_admin_dialogs_peer', password));
        await real(() => peer.rename('Тестовый собеседник'));
        final category = await real(
          () => admin.json(
            'POST',
            '/admin/categories',
            body: {'name': 'QaAdminDialogs'},
            status: 201,
          ),
        );
        final channels = <String, Map<String, dynamic>>{};
        for (final row in [
          ('QaAdminDialogsText', 'TEXT'),
          ('QaAdminDialogsOther', 'TEXT'),
          ('QaAdminDialogsVoice', 'VOICE'),
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
          expect(
            find.byTooltip('Закрыть навигацию').hitTestable(),
            findsNothing,
          );
        }

        phase = 'actual two participant LiveKit listener call';
        // Prepare the real prejoin surface without the drawer's intentional auto-join.
        final voice = state.topology!.categories
            .expand((c) => c.channels)
            .firstWhere((c) => c.id == channels['QaAdminDialogsVoice']!['id']);
        await real(() => state.selectChannel(voice));
        await settle();
        final lease = await real(
          () => peer.json(
            'POST',
            '/voice/channels/${channels['QaAdminDialogsVoice']!['id']}/leases',
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
        await selectChannel('QaAdminDialogsText');
        retained();
        expect(find.text('QaAdminDialogsText').hitTestable(), findsWidgets);
        await capture('native-connected-text-context');
        checks['drawer_channel_selection_closes_context_and_voice_retained'] =
            'PASS';
        phase = 'seven actual admin sections while SFU connected';
        await tester.enterText(composer(), 'QA_LOCAL_UNSENT');
        FocusManager.instance.primaryFocus?.unfocus();
        await choosePanel('Администрирование');
        expect(state.workspacePanel, WorkspacePanel.admin);
        for (final section in [
          'guild',
          'members',
          'roles',
          'channels',
          'audit',
          'media',
          'readiness',
        ]) {
          final tab = find.byKey(ValueKey('admin-section-tab-$section'));
          await tester.ensureVisible(tab);
          await settle();
          expect(tab.hitTestable(), findsOneWidget);
          await tester.tap(tab);
          await settle();
          retained();
          expect(
            find.byKey(const ValueKey('admin-workspace-header')),
            findsOneWidget,
          );
          await capture('native-admin-$section');
          checks['295_actual_section_${section}_context_voice'] = 'PASS';
        }
        phase = 'admin return and reopen retains selected section';
        await tester.tap(find.byKey(const ValueKey('admin-workspace-close')));
        await settle();
        expect(state.workspacePanel, WorkspacePanel.none);
        await closeNav();
        expect(
          state.selectedChannel?.id,
          channels['QaAdminDialogsText']!['id'],
        );
        expect(draft(), 'QA_LOCAL_UNSENT');
        retained();
        checks['295_Close_retains_conversation_draft_and_voice'] = 'PASS';
        await choosePanel('Администрирование');
        await settle();
        final activeReadiness = tester.widget<Semantics>(
          find.byKey(const ValueKey('admin-section-tab-readiness')),
        );
        observations['admin_reopened_readiness_selected'] =
            activeReadiness.properties.selected;
        checks['295_reopen_retains_previous_admin_section'] =
            activeReadiness.properties.selected == true ? 'PASS' : 'FAIL';
        await tester.tap(find.byKey(const ValueKey('admin-workspace-close')));
        await settle();
        await nav();
        phase = 'create dialog invalid validation and Cancel';
        await tester.tap(find.byTooltip('Создать раздел или канал'));
        await settle();
        final nameField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Имя',
        );
        expect(nameField.hitTestable(), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
        await settle();
        expect(find.text('Введите имя до 80 символов.'), findsOneWidget);
        await capture('native-create-invalid');
        final count = observed.categoryCreates;
        await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
        await settle();
        expect(observed.categoryCreates, count);
        retained();
        checks['298_create_invalid_Cancel_no_mutation'] = 'PASS';
        phase = 'create actual HTTP response held to inspect pending';
        await tester.tap(find.byTooltip('Создать раздел или канал'));
        await settle();
        await tester.enterText(nameField, 'QaRuntimeCreated');
        FocusManager.instance.primaryFocus?.unfocus();
        final hold = Completer<void>();
        observed.createResponseHold = hold;
        addTearDown(() {
          if (!hold.isCompleted) hold.complete();
        });
        await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
        await tester.pump();
        await waitFor(
          () => observed.categoryCreates == count + 1,
          'single real create dispatched',
        );
        expect(find.text('Создаём…'), findsOneWidget);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Отмена'))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Создаём…'),
              )
              .onPressed,
          isNull,
        );
        await capture('native-create-pending');
        expect(observed.categoryCreates, count + 1);
        hold.complete();
        observed.createResponseHold = null;
        await waitFor(
          () => find.byType(AlertDialog).evaluate().isEmpty,
          'actual category HTTP completed',
        );
        expect(
          state.topology!.categories.any((c) => c.name == 'QaRuntimeCreated'),
          true,
        );
        retained();
        checks['298_create_real_HTTP_pending_single_submit_success'] = 'PASS';
        await closeNav();
        phase = 'role destructive permission confirmation Cancel Escape Back';
        await choosePanel('Администрирование');
        final rolesTab = find.byKey(const ValueKey('admin-section-tab-roles'));
        await tester.ensureVisible(rolesTab);
        await tester.tap(rolesTab);
        await settle();
        await waitFor(
          () => find
              .widgetWithText(CheckboxListTile, 'Удалять текстовые каналы')
              .evaluate()
              .isNotEmpty,
          'actual role permissions',
        );
        final deletePermission = find.widgetWithText(
          CheckboxListTile,
          'Удалять текстовые каналы',
        );
        await tester.ensureVisible(deletePermission);
        await settle();
        await tester.tap(deletePermission);
        await settle();
        final saveRoles = find.widgetWithText(FilledButton, 'Сохранить');
        await tester.ensureVisible(saveRoles);
        await settle();
        await tester.tap(saveRoles);
        await settle();
        expect(find.text('Выдать права удаления?'), findsOneWidget);
        await capture('native-danger-confirmation');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle();
        expect(find.text('Выдать права удаления?'), findsNothing);
        retained();
        await tester.tap(saveRoles);
        await settle();
        await back();
        expect(find.text('Выдать права удаления?'), findsNothing);
        expect(tester.widget<CheckboxListTile>(deletePermission).value, true);
        retained();
        checks['298_danger_confirmation_Escape_Back_retains_draft_voice'] =
            'PASS';
        phase = 'confirmed role save actual API';
        await tester.tap(saveRoles);
        await settle();
        await tester.tap(find.widgetWithText(FilledButton, 'Выдать'));
        await waitFor(
          () => observed.roleSaveStatuses.isNotEmpty,
          'actual role permission response',
        );
        observations['role_save_HTTP_statuses'] = observed.roleSaveStatuses;
        expect(observed.roleSaveStatuses.last, 200);
        await tester.drag(
          find.ancestor(of: saveRoles, matching: find.byType(Scrollable)).first,
          const Offset(0, -320),
        );
        await settle();
        await waitFor(
          () => find.text('Разрешения сохранены.').evaluate().isNotEmpty,
          'actual role permission save feedback',
        );
        await capture('native-role-success');
        retained();
        checks['298_confirmed_role_save_real_API'] = 'PASS';
        // Clear unsent application draft before leaving the owned session.
        await tester.tap(find.byKey(const ValueKey('admin-workspace-close')));
        await settle();
        await closeNav();
        await tester.enterText(composer(), '');
        phase = 'real member admin ACL';
        await real(() => peer.json('GET', '/admin/roles', status: 403));
        checks['295_real_MEMBER_admin_roles_HTTP403'] = 'PASS';
        phase = 'owned logout and RTC release';
        await real(state.logout);
        await settle();
        expect(state.phase, AppPhase.signedOut);
        expect(state.room, isNull);
        await real(peerRoom.disconnect);
        await real(
          () =>
              peer.json('DELETE', '/voice/leases/${lease['id']}', status: 204),
        );
        checks['owned_logout_and_voice_release'] = 'PASS';
        report['status'] = 'PARTIAL';
        report['Back_input'] = 'integration binding handlePopRoute; OS hardware Back/gesture not exercised';
      } catch (error, stack) {
        report.addAll({
          'status': 'FAIL',
          'failed_phase': phase,
          'error_type': error.runtimeType.toString(),
          'failed_test_line': int.tryParse(
            RegExp(r'admin_dialogs_qa_test.dart:(\d+):')
                    .firstMatch(stack.toString())
                    ?.group(1) ??
                '',
          ),
        });
        binding.reportData = {
          ...?binding.reportData,
          'admin_dialogs_qa': report,
        };
        rethrow;
      }
      binding.reportData = {...?binding.reportData, 'admin_dialogs_qa': report};
    },
  );
}
