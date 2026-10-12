import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/services/composer_draft_memory.dart';
import 'package:boohtacord_desktop/src/models.dart';

import 'guild_identity_fixture.dart';

class DmQaTls extends HttpOverrides {
  DmQaTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? c) => super.createHttpClient(c)
    ..badCertificateCallback = (cert, host, port) =>
        host == 'localhost' &&
        port == 4940 &&
        sha256.convert(cert.der).toString() == pin;
}

class DmObservedClient extends http.BaseClient {
  final delegate = http.Client();
  int sends = 0, searches = 0;
  String? lastSearchDirect;
  int? lastSearchStatus;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) {
    if (r.method == 'POST' &&
        RegExp(r'/direct-messages/[^/]+/messages$').hasMatch(r.url.path)) {
      sends++;
    }
    return delegate.send(r).then((v) {
      if (r.url.path.endsWith('/search/messages')) {
        searches++;
        lastSearchDirect =
            r.url.queryParameters['dm_id'] ??
            r.url.queryParameters['direct_message_id'];
        lastSearchStatus = v.statusCode;
      }
      return v;
    });
  }

  @override
  void close() => delegate.close();
}

class DmLifecycleObserver with WidgetsBindingObserver {
  int paused = 0, resumed = 0;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) paused++;
    if (state == AppLifecycleState.resumed) resumed++;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual DM composer search context on owned native device', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD');
    if (origin != 'https://localhost:4940/api/v1' ||
        pin.length != 64 ||
        password.isEmpty) {
      throw StateError('Owned QA294 configuration required');
    }
    HttpOverrides.global = DmQaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final admin = FixtureSession(origin),
        peer = FixtureSession(origin),
        observed = DmObservedClient(),
        state = AppState(ApiClient(client: observed));
    final lifecycle = DmLifecycleObserver();
    WidgetsBinding.instance.addObserver(lifecycle);
    addTearDown(() {
      WidgetsBinding.instance.removeObserver(lifecycle);
      state.dispose();
      observed.close();
      admin.close();
      peer.close();
    });
    final report = <String, dynamic>{
      'issue': 294,
      'status': 'RUNNING',
      'platform': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
      'physical_device': false,
      'mocks': false,
      'checks': <String, String>{},
      'observations': <String, dynamic>{},
      'remaining': [
        'physical device touch/IME/image picker and clipboard gesture',
        'real-user transition/time measurement',
        'physical background foreground and screen reader',
      ],
    };
    final checks = report['checks'] as Map<String, String>,
        observations = report['observations'] as Map<String, dynamic>;
    var phase = 'fixtures';
    Future<T> real<T>(Future<T> Function() action) async =>
        (await tester.runAsync<T>(action)) as T;
    Future<void> waitFor(bool Function() condition, String label) async {
      for (var i = 0; i < 200 && !condition(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump();
      }
      expect(condition(), true, reason: label);
    }

    Future<void> settle() async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await binding.takeScreenshot(name);
    }

    Finder composer() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Написать сообщение…',
    );
    Finder search() => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Поиск сообщений',
    );
    String draft() => tester.widget<TextField>(composer()).controller!.text;
    Future<void> enter(Finder field, String text) async {
      await tester.tap(field.hitTestable());
      await tester.pump();
      await tester.enterText(field, text);
      expect(tester.widget<TextField>(field).controller!.text, text);
    }

    Future<void> closeNav() async {
      final f = find.byTooltip('Закрыть навигацию').hitTestable();
      if (f.evaluate().isNotEmpty) {
        await tester.tap(f.first);
        await settle();
      }
    }

    Future<void> nav() async {
      await closeNav();
      await tester.tap(find.byTooltip('Открыть навигацию').hitTestable().first);
      await settle();
    }

    Future<void> direct(String label) async {
      await nav();
      await tester.tap(find.text('Личные').last);
      await settle();
      await tester.tap(find.text(label).hitTestable().first);
      await waitFor(
        () =>
            state.selectedDirectMessage?.displayName == label &&
            !state.loadingDirectMessages,
        'actual selected DM history completed',
      );
      await settle();
      await closeNav();
    }

    Future<void> openSearch() async {
      await nav();
      await tester.tap(find.byTooltip('Поиск сообщений').hitTestable().first);
      await settle();
    }

    Future<void> closeSearch() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle();
      await closeNav();
    }

    Future<void> query(String text) async {
      final before = observed.searches;
      await enter(search(), text);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await waitFor(
        () => observed.searches > before,
        'actual search HTTP completed',
      );
      await settle();
    }

    try {
      final name = 'qa294_native_${Platform.operatingSystem}';
      late Map<String, dynamic> b, c, dm;
      await real(() async {
        await admin.login('qa_admin', password);
        await admin.json(
          'POST',
          '/auth/register',
          body: {'login': name, 'password': password},
          status: 201,
        );
        b = await admin.json(
          'POST',
          '/auth/register',
          body: {'login': 'qa294_peer_b', 'password': password},
          status: 201,
        );
        c = await admin.json(
          'POST',
          '/auth/register',
          body: {'login': 'qa294_peer_c', 'password': password},
          status: 201,
        );
        final cat = await admin.json(
          'POST',
          '/admin/categories',
          body: {'name': 'DmLab'},
          status: 201,
        );
        await admin.json(
          'POST',
          '/admin/categories/${cat['id']}/channels',
          body: {'name': 'DmText', 'kind': 'TEXT'},
          status: 201,
        );
        await peer.login(name, password);
        dm = await peer.json(
          'POST',
          '/direct-messages',
          body: {'participant_id': b['id']},
          status: 201,
        );
        await peer.json(
          'POST',
          '/direct-messages',
          body: {'participant_id': c['id']},
          status: 201,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_url', origin);
        await state.initialize();
        await state.authenticate(name, password, register: false);
      });
      await tester.pumpWidget(BoohtacordApp(state: state));
      await settle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
      }
      phase = 'actual DM list and empty conversation';
      await nav();
      await tester.tap(find.text('Личные').last);
      await settle();
      expect(find.text('qa294_peer_b').hitTestable(), findsWidgets);
      expect(find.text('qa294_peer_c').hitTestable(), findsWidgets);
      await capture('native-dm-list');
      await closeNav();
      await direct('qa294_peer_b');
      expect(state.directMessageHistory, isEmpty);
      expect(find.textContaining('Начните диалог'), findsWidgets);
      expect(composer(), findsOneWidget);
      await capture('native-empty-dm');
      checks['list_empty_composer_visible'] = 'PASS';
      phase = 'actual UI send and server history';
      await enter(composer(), 'QA294 synthetic anchor');
      await tester.tap(
        find.byTooltip('Отправить личное сообщение').hitTestable(),
      );
      await waitFor(
        () =>
            state.directMessageHistory.isNotEmpty &&
            observed.sends == 1 &&
            !state.sending &&
            draft().isEmpty,
        'actual UI send completed',
      );
      await settle();
      final message = state.directMessageHistory.first;
      final history = await real(
        () => peer.json('GET', '/direct-messages/${dm['id']}/messages'),
      );
      expect(
        (history['messages'] as List).any((m) => m['id'] == message.id),
        true,
      );
      await capture('native-dm-conversation');
      checks['UI_send_real_history'] = 'PASS';
      phase = 'per-DM unsent draft isolation';
      final draftEpoch = ComposerDraftMemory.epoch;
      void observeDraft(String step) {
        final selected = state.selectedDirectMessage;
        final account = state.user;
        observations[step] = <String, Object?>{
          'selected_expected_b': selected?.id == dm['id'],
          'selected_expected_c': selected?.participantId == c['id'],
          'loading': state.loadingDirectMessages,
          'sending': state.sending,
          'account_present': account != null,
          'epoch_unchanged': ComposerDraftMemory.epoch == draftEpoch,
          'controller_length': draft().length,
          'stored_length': account == null || selected == null
              ? null
              : ComposerDraftMemory.load<DirectChatMessage>(
                  account.accountId,
                  ComposerDraftKind.directMessage,
                  selected.id,
                )?.body.length,
        };
      }

      await enter(composer(), 'QA294 draft B');
      expect(draft(), 'QA294 draft B');
      observeDraft('draft_b_entered');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await direct('qa294_peer_c');
      observeDraft('draft_c_selected');
      expect(draft(), isEmpty);
      await enter(composer(), 'QA294 draft C');
      expect(draft(), 'QA294 draft C');
      observeDraft('draft_c_entered');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await direct('qa294_peer_b');
      observeDraft('draft_b_returned');
      await capture('native-draft-return');
      expect(draft(), 'QA294 draft B');
      checks['per_conversation_drafts'] = 'PASS';
      phase = 'actual DM search result context and return';
      await openSearch();
      await query('QA294 synthetic anchor');
      expect(observed.lastSearchStatus, 200);
      final hit = find.byKey(ValueKey('search-result-${message.id}'));
      await waitFor(() => hit.evaluate().isNotEmpty, 'real DM hit');
      await capture('native-dm-search');
      await tester.tap(hit);
      await waitFor(
        () => !state.loadingSearchContext,
        'real source context history',
      );
      await settle();
      expect(state.workspacePanel, WorkspacePanel.searchContext);
      expect(state.searchContextError, isNull);
      await capture('native-result-context');
      final back = find.byTooltip('Вернуться к беседе');
      await tester.tap(
        back.evaluate().isNotEmpty ? back : find.text('Вернуться к беседе'),
      );
      await waitFor(
        () =>
            state.workspacePanel == WorkspacePanel.none &&
            !state.loadingDirectMessages,
        'return original DM',
      );
      await settle();
      await closeNav();
      expect(state.selectedDirectMessage?.id, dm['id']);
      expect(draft(), 'QA294 draft B');
      checks['search_result_original_context_draft'] = 'PASS';
      phase = 'scope query and resize restoration';
      await openSearch();
      expect(
        tester.widget<TextField>(search()).controller!.text,
        'QA294 synthetic anchor',
      );
      final scope = find.byKey(const ValueKey('workspace-search-scope'));
      await tester.tap(scope);
      await settle();
      await tester.tap(find.text('Везде').last);
      await settle();
      await query('QA294 synthetic anchor');
      final oldSize = tester.view.physicalSize,
          ratio = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(1440 * ratio, 900 * ratio);
      await settle();
      tester.view.physicalSize = oldSize;
      await settle();
      expect(
        tester.widget<TextField>(search()).controller!.text,
        'QA294 synthetic anchor',
      );
      expect(
        tester.widget<DropdownButtonFormField<String>>(scope).initialValue,
        'all',
      );
      await capture('native-search-restored');
      await closeSearch();
      await direct('qa294_peer_c');
      await openSearch();
      expect(tester.widget<TextField>(search()).controller!.text, isEmpty);
      await closeSearch();
      await direct('qa294_peer_b');
      await openSearch();
      expect(
        tester.widget<TextField>(search()).controller!.text,
        'QA294 synthetic anchor',
      );
      expect(
        tester.widget<DropdownButtonFormField<String>>(scope).initialValue,
        'all',
      );
      await closeSearch();
      expect(draft(), 'QA294 draft B');
      checks['per_origin_query_scope_back_resize'] = 'PASS';
      phase =
          'actual OS clipboard controlled paste and long multiline composer';
      await real(
        () => Clipboard.setData(
          const ClipboardData(text: 'QA294 clipboard fixture'),
        ),
      );
      await tester.tap(composer());
      await tester.pump();
      final editable = find.descendant(
        of: composer(),
        matching: find.byType(EditableText),
      );
      await real(
        () => tester
            .state<EditableTextState>(editable)
            .pasteText(SelectionChangedCause.toolbar),
      );
      await tester.pump();
      expect(draft(), contains('QA294 clipboard fixture'));
      checks['OS_clipboard_controlled_paste'] = 'PASS';
      observations['clipboard_method'] = 'Actual platform Clipboard.setData/getData via EditableTextState.pasteText; controlled Flutter action, not physical paste gesture';
      await tester.enterText(
        composer(),
        List.generate(9, (i) => 'QA294 multiline ${i + 1}').join('\n'),
      );
      await tester.tap(composer());
      await tester.pump();
      await real(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pump();
      final media = MediaQuery.of(tester.element(composer()));
      observations['actual_IME_inset_logical'] = media.viewInsets.bottom;
      observations['safe_area_padding_logical'] = media.padding.bottom;
      expect(tester.getRect(composer()).width, greaterThan(0));
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await capture('native-long-multiline-composer');
      checks['long_multiline_composer_layout'] = 'PASS';
      phase = 'actual Android OS lifecycle preserves draft';
      if (Platform.isAndroid) {
        final beforePaused = lifecycle.paused,
            beforeResumed = lifecycle.resumed,
            oldDraft = draft();
        final response = await real(
          () => http
              .post(
                Uri.parse('http://localhost:4944/background-resume'),
                headers: {
                  'X-QA-Control': const String.fromEnvironment(
                    'QA_CONTROL_KEY',
                  ),
                },
              )
              .timeout(const Duration(seconds: 30)),
        );
        expect(response.statusCode, 204);
        await waitFor(
          () =>
              lifecycle.paused > beforePaused &&
              lifecycle.resumed > beforeResumed,
          'actual OS pause/resume observer',
        );
        await settle();
        expect(draft(), oldDraft);
        checks['emulator_OS_background_foreground_draft'] = 'PASS';
        observations['lifecycle_dispatch'] = 'adb KEYCODE_HOME then explicit launch of owned QA package; actual Android lifecycle observer';
      } else {
        observations['OS_background_foreground'] = 'NOT_RUN';
      }
      phase = 'negative actual administrator DM ACL';
      final denied = await real(
        () => admin.request('GET', '/direct-messages/${dm['id']}/messages'),
      );
      final searchDenied = await real(
        () => admin.request(
          'GET',
          '/search/messages?query=QA294&direct_message_id=${dm['id']}',
        ),
      );
      expect(denied.statusCode, 404);
      expect([403, 404], contains(searchDenied.statusCode));
      observations['third_admin_DM_history_HTTP'] = denied.statusCode;
      observations['third_admin_DM_search_HTTP'] = searchDenied.statusCode;
      checks['real_server_third_admin_DM_ACL'] = 'PASS';
      await capture('native-original-context-final');
      report['status'] = 'PASS';
    } catch (error, stack) {
      report['status'] = 'FAIL';
      report['failed_at'] = phase;
      report['error_type'] = error.runtimeType.toString();
      report['failed_source_line'] = RegExp(r'dm_composer_qa_test.dart:(\d+)')
          .firstMatch(stack.toString())
          ?.group(1);
      rethrow;
    } finally {
      binding.reportData = {...?binding.reportData, 'dm_composer_qa': report};
    }
  });
}
