import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart' as lk show ConnectionState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/pinned_screen_mini_player/component.dart';

import 'guild_identity_fixture.dart';

class MiniPlayerQaTls extends HttpOverrides {
  MiniPlayerQaTls(this.pin);
  final String pin;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) =>
            host == 'localhost' &&
            port == 4830 &&
            sha256.convert(cert.der).toString() == pin;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real native pinned screen receiver through owned API and SFU', (
    tester,
  ) async {
    const origin = String.fromEnvironment('QA_API_BASE'),
        pin = String.fromEnvironment('QA_CERT_SHA256'),
        password = String.fromEnvironment('QA_PASSWORD'),
        sourceAccount = String.fromEnvironment('QA_SOURCE_ACCOUNT'),
        name = String.fromEnvironment('QA_NATIVE_LOGIN'),
        bridgeControl = String.fromEnvironment('QA_BRIDGE_CONTROL');
    if (origin != 'https://localhost:4830/api/v1' ||
        pin.length != 64 ||
        password.isEmpty ||
        sourceAccount.isEmpty ||
        name.isEmpty) {
      throw StateError('Owned QA config required');
    }
    HttpOverrides.global = MiniPlayerQaTls(pin);
    addTearDown(() => HttpOverrides.global = null);
    final fixture = FixtureSession(origin);
    addTearDown(fixture.close);
    String? memberId;
    await tester.runAsync(() async {
      await fixture.login('qa_admin', password);
      final response = await fixture.request(
        'POST',
        '/auth/register',
        body: {'login': name, 'password': password},
      );
      if (response.statusCode == 201) {
        memberId =
            (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
      } else if (response.statusCode == 409) {
        // Reuse only this fixed synthetic account inside our owned disposable stack.
        final accounts = await fixture.json('GET', '/admin/accounts?limit=100');
        memberId =
            (accounts['accounts'] as List)
                    .cast<Map<String, dynamic>>()
                    .singleWhere((a) => a['login'] == name)['account_id']
                as String;
        await fixture.json(
          'PATCH',
          '/admin/accounts/$memberId',
          body: {'role': 'MEMBER', 'blocked': false},
        );
      } else {
        throw StateError('Fixture registration HTTP ${response.statusCode}');
      }
    });
    final member = FixtureSession(origin);
    addTearDown(member.close);
    await tester.runAsync(() async {
      await member.login(name, password);
      await member.json(
        'PATCH',
        '/me',
        body: {'display_name': 'Нативный просмотр'},
      );
      await member.json(
        'POST',
        '/direct-messages',
        body: {'participant_id': sourceAccount},
        status: 201,
      );
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', origin);
    final state = AppState(ApiClient());
    addTearDown(state.dispose);
    final report = <String, dynamic>{
      'issue': 247,
      'status': 'RUNNING',
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'actual_api': true,
      'actual_sfu': true,
      'synthetic_source': 'production Web publisher canvas plus tone',
      'checks': <String, String>{},
      'observations': <Map<String, dynamic>>[],
    };
    final checks = report['checks'] as Map<String, String>,
        observations = report['observations'] as List<Map<String, dynamic>>;
    final renderKey = GlobalKey();
    String phase = 'login';
    void mark(String label) {
      phase = label;
      debugPrint('QA247_PHASE: $label');
    }

    mark('login');
    Future<void> waitFor(bool Function() test, {int seconds = 45}) async {
      for (var i = 0; i < seconds * 4 && !test(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      expect(test(), true, reason: 'QA phase $phase');
    }

    Future<void> capture(String label, {bool engineRaster = false}) async {
      await tester.pump();
      expect(tester.takeException(), isNull);
      mark('capture $label');
      if (engineRaster) {
        final boundary =
            renderKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bytes = await tester
            .runAsync(() async {
              final image = await boundary.toImage(
                pixelRatio: tester.view.devicePixelRatio,
              );
              try {
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                return data!.buffer.asUint8List().toList();
              } finally {
                image.dispose();
              }
            })
            .timeout(const Duration(seconds: 30));
        final data = binding.reportData ??= <String, dynamic>{};
        final screenshots = data.putIfAbsent(
          'screenshots',
          () => <Map<String, dynamic>>[],
        ) as List<dynamic>;
        screenshots.add({'screenshotName': label, 'bytes': bytes});
        report['adaptive_capture_method'] = 'actual Flutter RepaintBoundary.toImage of running app, engine viewport override; not OS screenshot';
        return;
      }
      var complete = false;
      final future = binding
          .takeScreenshot(label)
          .whenComplete(() => complete = true);
      for (var i = 0; i < 120 && !complete; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      await future.timeout(const Duration(seconds: 1));
    }

    Future<void> sourceAction(String action) async {
      await tester.runAsync(() async {
        final client = HttpClient();
        try {
          await (() async {
            final request = await client.postUrl(
              Uri.parse('http://localhost:4834/publisher'),
            );
            request.headers.set('X-QA-Control', bridgeControl);
            request.headers.contentType = ContentType.json;
            final payload = utf8.encode(jsonEncode({'action': action}));
            request.contentLength = payload.length;
            request.add(payload);
            final response = await request.close();
            final data = await utf8.decoder.bind(response).join();
            expect(
              response.statusCode,
              200,
              reason: 'Actual publisher UI control',
            );
            expect(
              (jsonDecode(data) as Map<String, dynamic>)['actual_publisher_ui'],
              true,
            );
            expect(
              (jsonDecode(data) as Map<String, dynamic>)['action'],
              action,
            );
          })().timeout(const Duration(seconds: 50));
        } finally {
          client.close(force: true);
        }
      });
    }

    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: renderKey,
          child: BoohtacordApp(state: state),
        ),
      );
      await tester.runAsync(state.initialize);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      if (state.phase == AppPhase.ready) {
        await tester.runAsync(state.logout);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), name);
      await tester.enterText(fields.at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('Войти').last);
      await waitFor(() => state.phase == AppPhase.ready);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }
      final channels = state.topology!.categories
          .expand((c) => c.channels)
          .toList();
      final voice = channels.firstWhere((c) => c.name == 'QaScreen'),
          text = channels.firstWhere((c) => c.name == 'QaText');
      mark('join real voice');
      await tester.runAsync(() => state.selectChannel(voice));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      final closeDrawer = find.byTooltip('Закрыть навигацию').hitTestable();
      if (closeDrawer.evaluate().isNotEmpty) {
        await tester.tap(closeDrawer);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }
      await tester.tap(find.text('Подключиться без микрофона').last);
      await waitFor(
        () => state.room?.connectionState == lk.ConnectionState.connected,
        seconds: 60,
      );
      await waitFor(() => find.text('Смотреть экран').evaluate().isNotEmpty);
      await tester.ensureVisible(find.text('Смотреть экран').first);
      await tester.tap(find.text('Смотреть экран').first);
      mark('first actual decoded/rendered frame');
      await waitFor(
        () => state.voice.remoteScreenViewerFirstFrameGeneration != null,
        seconds: 60,
      );
      final selected = state.voice.selectedRemoteScreenViewerPublication!,
          selectedTrack = selected.track!;
      final selectedAudio =
              state.voice.selectedRemoteScreenViewerAudioPublication!,
          selectedAudioTrack = selectedAudio.track!;
      final room = state.room!, listener = room.createListener();
      addTearDown(listener.dispose);
      var subscribed = 0, unsubscribed = 0;
      listener.on<TrackSubscribedEvent>((e) {
        if (e.publication.source == TrackSource.screenShareVideo ||
            e.publication.source == TrackSource.screenShareAudio) {
          subscribed++;
        }
      });
      listener.on<TrackUnsubscribedEvent>((e) {
        if (e.publication.source == TrackSource.screenShareVideo ||
            e.publication.source == TrackSource.screenShareAudio) {
          unsubscribed++;
        }
      });
      final revision = state.voice.screenViewerSelectionRevision;
      Future<void> snapshot(String label, {bool preserve = true}) async {
        if (preserve) {
          expect(
            identical(
              state.voice.selectedRemoteScreenViewerPublication,
              selected,
            ),
            true,
          );
          expect(identical(selected.track, selectedTrack), true);
          expect(identical(selectedAudio.track, selectedAudioTrack), true);
          expect(state.voice.screenViewerSelectionRevision, revision);
        }
        final pubs = room.remoteParticipants.values.expand(
          (p) => p.trackPublications.values,
        );
        final tracks = pubs
            .where(
              (p) => p.subscribed && p.source == TrackSource.screenShareVideo,
            )
            .length;
        final audios = pubs
            .where(
              (p) => p.subscribed && p.source == TrackSource.screenShareAudio,
            )
            .length;
        final decoded = selected.track is RemoteVideoTrack
            ? await tester.runAsync(
                () => (selected.track as RemoteVideoTrack).getReceiverStats(),
              )
            : null;
        final audioStats = selectedAudio.track is RemoteAudioTrack
            ? await tester.runAsync(
                () => (selectedAudio.track as RemoteAudioTrack)
                    .getReceiverStats(),
              )
            : null;
        observations.add({
          'name': label,
          'screen_video_subscriptions': tracks,
          'screen_audio_subscriptions': audios,
          'video_renderers': find.byType(VideoTrackRenderer).evaluate().length,
          'decoded_frames': decoded?.framesDecoded,
          'audio_packets_received': audioStats?.packetsReceived,
          'subscribe_events_since_selection': subscribed,
          'unsubscribe_events_since_selection': unsubscribed,
        });
        if (preserve) {
          expect(tracks, 1);
          expect(audios, 1);
          expect(find.byType(VideoTrackRenderer), findsOneWidget);
          expect(decoded?.framesDecoded, greaterThan(0));
          expect(audioStats?.packetsReceived, greaterThan(0));
        }
      }

      await snapshot('full');
      await capture('mini-native-full');
      mark('pin TEXT DM settings');
      await tester.tap(find.byTooltip('Закрепить демонстрацию'));
      await tester.pump();
      await tester.runAsync(() => state.selectChannel(text));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(find.byType(WorkspacePinnedScreenMiniPlayer), findsOneWidget);
      await snapshot('pinned TEXT');
      expect(
        tester
            .getRect(find.byType(WorkspacePinnedScreenMiniPlayer))
            .overlaps(tester.getRect(find.byType(TextField).last)),
        false,
        reason: 'Mini must not obscure TEXT composer',
      );
      await capture('mini-native-text');
      await tester.runAsync(
        () => state.openDirectConversation(state.directMessages.first),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await snapshot('pinned DM');
      expect(
        tester
            .getRect(find.byType(WorkspacePinnedScreenMiniPlayer))
            .overlaps(tester.getRect(find.byType(TextField).last)),
        false,
        reason: 'Mini must not obscure DM composer',
      );
      await capture('mini-native-dm');
      state.toggleWorkspacePanel(WorkspacePanel.profile);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await snapshot('pinned settings');
      await capture('mini-native-settings');
      expect(subscribed, 0);
      expect(unsubscribed, 0);
      checks['pin_TEXT_DM_settings_one_receiver_no_resubscription'] = 'PASS';
      state.toggleWorkspacePanel(WorkspacePanel.profile);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      mark('mini return full fullscreen return');
      await tester.tap(find.byTooltip('К голосу'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await snapshot('return full');
      await tester.tap(find.byTooltip('Развернуть демонстрацию на весь экран'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await snapshot('fullscreen');
      await capture('mini-native-fullscreen');
      await tester.tap(find.byTooltip('Выйти из полноэкранного режима'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      await snapshot('fullscreen return');
      expect(subscribed, 0);
      expect(unsubscribed, 0);
      checks['full_mini_full_return_preserves_subscription'] = 'PASS';
      mark('mute stop');
      await tester.runAsync(() => state.selectChannel(text));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      final mini = find.byType(WorkspacePinnedScreenMiniPlayer);
      await tester.tap(
        find.descendant(of: mini, matching: find.byTooltip('Выключить звук')),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(
        state.screenShareAudioMuted(room.remoteParticipants.values.single),
        true,
      );
      expect(
        find.descendant(of: mini, matching: find.byTooltip('Включить звук')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: mini, matching: find.byTooltip('Включить звук')),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(
        state.screenShareAudioMuted(room.remoteParticipants.values.single),
        false,
      );
      await tester.tap(
        find.descendant(
          of: mini,
          matching: find.byTooltip('Остановить просмотр'),
        ),
      );
      await waitFor(
        () =>
            state.voice.selectedRemoteScreenViewerIdentity == null &&
            !selected.subscribed &&
            !selectedAudio.subscribed,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(unsubscribed, 2);
      expect(find.byType(VideoTrackRenderer), findsNothing);
      checks['stop_exactly_once_and_mute'] = 'PASS';
      await capture('mini-native-stopped');
      Future<void> unpinnedReceiver() async {
        await tester.runAsync(() => state.selectChannel(voice));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        await tester.ensureVisible(find.text('Смотреть экран').first);
        await tester.tap(find.text('Смотреть экран').first);
        await waitFor(
          () => state.voice.remoteScreenViewerFirstFrameGeneration != null,
          seconds: 60,
        );
      }

      mark('no pin default route stop');
      await unpinnedReceiver();
      await tester.runAsync(() => state.selectChannel(text));
      await waitFor(
        () => state.voice.selectedRemoteScreenViewerIdentity == null,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(find.byType(VideoTrackRenderer), findsNothing);
      expect(unsubscribed, 4);
      await unpinnedReceiver();
      await tester.runAsync(
        () => state.openDirectConversation(state.directMessages.first),
      );
      await waitFor(
        () => state.voice.selectedRemoteScreenViewerIdentity == null,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(find.byType(VideoTrackRenderer), findsNothing);
      await unpinnedReceiver();
      state.toggleWorkspacePanel(WorkspacePanel.profile);
      await waitFor(
        () => state.voice.selectedRemoteScreenViewerIdentity == null,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(find.byType(VideoTrackRenderer), findsNothing);
      state.toggleWorkspacePanel(WorkspacePanel.profile);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      checks['no_pin_default_route_stop'] = 'PASS';
      mark('unpinned source restart outside voice cannot revive');
      await unpinnedReceiver();
      mark('source remove request');
      await sourceAction('remove');
      mark('source remove acknowledged');
      await waitFor(
        () => state.voice.selectedRemoteScreenViewerIdentity == null,
      );
      await tester.runAsync(() => state.selectChannel(text));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      mark('source publish request');
      await sourceAction('publish');
      mark('source publish acknowledged');
      await capture('mini-native-source-republished');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      expect(state.voice.selectedRemoteScreenViewerIdentity, isNull);
      expect(find.byType(VideoTrackRenderer), findsNothing);
      checks['unpinned_source_restart_outside_voice_does_not_resubscribe'] =
          'PASS';
      Future<void> pinnedReceiver() async {
        await tester.runAsync(() => state.selectChannel(voice));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        if (state.room == null) {
          final close = find.byTooltip('Закрыть навигацию').hitTestable();
          if (close.evaluate().isNotEmpty) {
            await tester.tap(close);
            await tester.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 30),
            );
          }
          await tester.tap(find.text('Подключиться без микрофона').last);
          await waitFor(
            () => state.room?.connectionState == lk.ConnectionState.connected,
            seconds: 60,
          );
        }
        await waitFor(() => find.text('Смотреть экран').evaluate().isNotEmpty);
        await tester.ensureVisible(find.text('Смотреть экран').first);
        await tester.tap(find.text('Смотреть экран').first);
        await waitFor(
          () => state.voice.remoteScreenViewerFirstFrameGeneration != null,
          seconds: 60,
        );
        await tester.tap(find.byTooltip('Закрепить демонстрацию'));
        await tester.runAsync(() => state.selectChannel(text));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        expect(find.byType(WorkspacePinnedScreenMiniPlayer), findsOneWidget);
      }

      Future<void> cleared() async {
        await waitFor(
          () => state.voice.selectedRemoteScreenViewerIdentity == null,
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        expect(find.byType(VideoTrackRenderer), findsNothing);
        expect(find.byType(WorkspacePinnedScreenMiniPlayer), findsNothing);
      }

      Future<void> loginUi(String account) async {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        final inputs = find.byType(TextFormField);
        await tester.enterText(inputs.at(0), account);
        await tester.enterText(inputs.at(1), password);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.tap(find.text('Войти').last);
        await waitFor(() => state.phase == AppPhase.ready);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
      }

      mark('adaptive 320 viewport and keyboard focus');
      await pinnedReceiver();
      final initialSize = tester.view.physicalSize,
          ratio = tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [393.0, 320.0]) {
        tester.view.physicalSize = Size(width * ratio, initialSize.height);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        final miniWidget = find.byType(WorkspacePinnedScreenMiniPlayer);
        final bounds = tester.getRect(miniWidget);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(width + 1));
        for (final label in [
          'К голосу',
          'Выключить звук',
          'Остановить просмотр',
        ]) {
          final button = find.descendant(
            of: miniWidget,
            matching: find.byTooltip(label),
          );
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          expect(rect.left, greaterThanOrEqualTo(bounds.left));
          expect(rect.right, lessThanOrEqualTo(bounds.right + 1));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 1));
        }
        final target = find.descendant(
          of: miniWidget,
          matching: find.byTooltip('К голосу'),
        );
        final button = tester.widget<IconButton>(
          find.ancestor(of: target, matching: find.byType(IconButton)).first,
        );
        expect(button.onPressed, isNotNull);
        var miniFocused = false;
        for (var i = 0; i < 50 && !miniFocused; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          miniFocused =
              FocusManager.instance.primaryFocus?.context
                  ?.findAncestorWidgetOfExactType<
                    WorkspacePinnedScreenMiniPlayer
                  >() !=
              null;
        }
        expect(
          miniFocused,
          true,
          reason: 'Keyboard traversal reaches mini-player controls',
        );
        await capture('mini-native-width-${width.toInt()}', engineRaster: true);
      }
      tester.view.physicalSize = initialSize;
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      report['adaptive_method'] = 'real native renderer with explicit Flutter logical viewport override';
      checks['viewport_320_adaptive_focus'] = 'PASS';
      mark('actual publisher UI removal clears native receiver');
      mark('source remove request');
      await sourceAction('remove');
      mark('source remove acknowledged');
      await cleared();
      await capture('mini-native-source-removed');
      checks['source_removal_cleanup'] = 'PASS';
      mark('source publish request');
      await sourceAction('publish');
      mark('source publish acknowledged');
      await capture('mini-native-source-republished');
      mark('voice disconnect clears');
      await pinnedReceiver();
      final oldRoom = state.room!;
      await tester.runAsync(state.leaveVoice);
      await cleared();
      expect(oldRoom.connectionState, lk.ConnectionState.disconnected);
      expect(state.room, isNull);
      checks['disconnect_cleanup'] = 'PASS';
      await capture('mini-native-disconnected');
      mark('logout and account switch clears');
      await pinnedReceiver();
      await tester.runAsync(state.logout);
      await cleared();
      expect(state.room, isNull);
      await loginUi('qa_admin');
      await cleared();
      expect(state.room, isNull);
      checks['logout_account_switch_cleanup'] = 'PASS';
      await capture('mini-native-other-account');
      await tester.runAsync(state.logout);
      await loginUi(name);
      await pinnedReceiver();
      mark('real permission revoke clears');
      await tester.runAsync(
        () => fixture.json(
          'PATCH',
          '/admin/accounts/$memberId',
          body: {'role': 'MEMBER', 'blocked': true},
        ),
      );
      await waitFor(() => state.phase != AppPhase.ready, seconds: 60);
      await cleared();
      expect(state.room, isNull);
      checks['revoke_cleanup'] = 'PASS';
      await capture('mini-native-revoked');
      report['status'] = 'PASS';
    } catch (error) {
      report['status'] = 'FAIL';
      report['failed_at'] = phase;
      report['error_type'] = error.runtimeType.toString();
      try {
        await capture('mini-native-failure');
      } catch (_) {
        // Preserve the original failure even if the native screenshot cannot finish.
      }
      rethrow;
    } finally {
      binding.reportData = {...?binding.reportData, 'mini_player_qa': report};
      await tester.runAsync(state.leaveVoice);
    }
  });
}
