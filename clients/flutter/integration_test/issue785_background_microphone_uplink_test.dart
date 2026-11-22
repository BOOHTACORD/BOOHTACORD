import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/models.dart';

import '../test/test_support/app_resume_wait.dart';
import 'issue689_support.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android microphone publisher keeps paired RTP flowing through background resume',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      const channelId = String.fromEnvironment('QA_PAIR_CHANNEL_ID');
      const expectMicrophoneServiceStop = bool.fromEnvironment(
        'QA_EXPECT_MICROPHONE_SERVICE_STOP',
      );
      const expectMicrophonePermissionRevoke = bool.fromEnvironment(
        'QA_EXPECT_MICROPHONE_PERMISSION_REVOKE',
      );
      if (origin != 'https://localhost:4810/api/v1' ||
          pin.length != 64 ||
          password.isEmpty ||
          channelId.isEmpty ||
          !Platform.isAndroid) {
        throw StateError(
          'Owned Android microphone pair QA configuration required',
        );
      }
      HttpOverrides.global = QaTls(pin);
      addTearDown(() => HttpOverrides.global = null);

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

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'qa_admin');
      await tester.enterText(fields.at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.text('Войти').last);
      await waitFor(
        tester,
        () => app.phase == AppPhase.ready && app.realtime.connected,
      );

      await tester.runAsync(app.refreshTopology);
      final channel = app.topology!.categories
          .expand((category) => category.channels)
          .where((value) => value.id == channelId)
          .single;
      expect(channel.kind, ChannelKind.voice);
      await tester.runAsync(() => app.selectChannel(channel));
      await tester.pumpAndSettle();
      final logicalWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(logicalWidth - 8, 320));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Закрыть навигацию').hitTestable(),
        findsNothing,
        reason: 'close initial mobile navigation before the voice join',
      );
      await tester.runAsync(() => app.joinVoice(channel));
      await waitFor(
        tester,
        () =>
            app.voicePhase == VoicePhase.connected &&
            app.room != null &&
            app.voice.microphoneForeground.active &&
            app.room!.localParticipant!.audioTrackPublications.any(
              (publication) => publication.track != null && !publication.muted,
            ),
      );
      expect(app.voice.microphoneUnavailable, isFalse);
      final initialRoom = app.room!;
      final initialPublication = initialRoom
          .localParticipant!
          .audioTrackPublications
          .firstWhere(
            (publication) => publication.track != null && !publication.muted,
          );
      final initialTrack = initialPublication.track!;
      final initialTrackId = initialTrack.mediaStreamTrack.id;

      Future<Map<String, Object?>> readPublisherStats() async {
        final stats = await initialTrack.getSenderStats();
        return {
          'audioPublicationCount':
              initialRoom.localParticipant!.audioTrackPublications.length,
          'microphoneTrackEnabled': initialTrack.mediaStreamTrack.enabled,
          'packetsSent': stats?.packetsSent?.toInt() ?? 0,
          'bytesSent': stats?.bytesSent?.toInt() ?? 0,
        };
      }

      Future<Map<String, Object?>> waitForForegroundPublisherUplink() async {
        final initial = await readPublisherStats();
        final initialPackets = initial['packetsSent']! as int;
        final initialBytes = initial['bytesSent']! as int;
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          final current = await readPublisherStats();
          if ((current['packetsSent']! as int) > initialPackets &&
              (current['bytesSent']! as int) > initialBytes) {
            return current;
          }
        }
        throw TestFailure(
          'Android publisher RTP did not advance in foreground before backgrounding',
        );
      }

      final before = (await tester.runAsync(waitForForegroundPublisherUplink))!;
      expect(before['audioPublicationCount'], greaterThan(0));
      expect(before['microphoneTrackEnabled'], isTrue);
      expect(app.voice.microphoneForeground.active, isTrue);

      final temporaryDirectory = await getTemporaryDirectory();
      final control = File(
        '${temporaryDirectory.path}/issue785_flutter_uplink_control.json',
      );
      expect(await control.exists(), isFalse, reason: 'stale control file');
      await control.writeAsString(
        jsonEncode({'status': 'ready', 'publisherBeforeBackground': before}),
      );

      await tester.runAsync(
        () => waitForAppBackgroundThenResume(
          readLifecycleState: () => binding.lifecycleState,
          timeout: const Duration(minutes: 5),
          pollInterval: const Duration(seconds: 5),
        ),
      );
      final resumeCommand =
          jsonDecode(await control.readAsString()) as Map<String, dynamic>;
      expect(resumeCommand['status'], 'resume');
      final backgroundSeconds =
          (resumeCommand['backgroundSecondsObserved'] as num).toDouble();
      final backgroundStartedUnixMs =
          (resumeCommand['backgroundStartedUnixMs'] as num).toInt();
      final backgroundEndedUnixMs =
          (resumeCommand['backgroundEndedUnixMs'] as num).toInt();
      final serviceSamples =
          (resumeCommand['microphoneServiceSamples'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final serviceStopExpected =
          resumeCommand['expectedMicrophoneServiceStop'] == true;
      final permissionRevokeExpected =
          resumeCommand['expectedMicrophonePermissionRevoke'] == true;
      expect(serviceStopExpected, expectMicrophoneServiceStop);
      expect(permissionRevokeExpected, expectMicrophonePermissionRevoke);
      expect(serviceStopExpected && permissionRevokeExpected, isFalse);
      expect(backgroundSeconds, greaterThanOrEqualTo(120));
      expect(serviceSamples.length, greaterThanOrEqualTo(5));
      if (serviceStopExpected || permissionRevokeExpected) {
        expect(
          serviceSamples.first['microphone_foreground_service_active'],
          isTrue,
          reason: 'microphone FGS must be active before the injected stop',
        );
        expect(
          serviceSamples.any(
            (sample) => sample['microphone_foreground_service_active'] == false,
          ),
          isTrue,
          reason: 'runner must observe the injected microphone FGS stop',
        );
        await tester.runAsync(() => app.voice.microphoneTail);
        await waitFor(
          tester,
          () =>
              app.room != null &&
              app.voicePhase == VoicePhase.listener &&
              app.realtime.connected &&
              app.voice.microphoneMuted &&
              app.voice.microphoneUnavailable &&
              !app.voice.microphoneForeground.active,
        );
        expect(identical(app.room, initialRoom), isTrue);
        expect(
          initialRoom.localParticipant!.audioTrackPublications.any(
            (publication) => publication.track != null && !publication.muted,
          ),
          isFalse,
          reason: 'local microphone publication must be muted after FGS stop',
        );
        if (serviceStopExpected) {
          expect(app.error, contains('Android остановил службу микрофона'));
        } else {
          expect(app.error, isNotNull);
        }
        await tester.pumpAndSettle();
        expect(find.text('Микрофон недоступен'), findsOneWidget);
        expect(find.text('Повторить'), findsOneWidget);
      } else {
        expect(
          serviceSamples.every(
            (sample) => sample['microphone_foreground_service_active'] == true,
          ),
          isTrue,
          reason: 'microphone FGS must remain active across Android Home',
        );
        await waitFor(
          tester,
          () =>
              app.room != null &&
              app.voicePhase == VoicePhase.connected &&
              app.realtime.connected &&
              app.voice.microphoneForeground.active,
        );
        expect(identical(app.room, initialRoom), isTrue);
        expect(
          initialRoom.localParticipant!.audioTrackPublications.any(
            (publication) =>
                publication.track?.mediaStreamTrack.id == initialTrackId &&
                !publication.muted,
          ),
          isTrue,
          reason: 'the original microphone publication must survive background resume',
        );
        final afterResume = (await tester.runAsync(readPublisherStats))!;
        expect(afterResume['microphoneTrackEnabled'], isTrue);
        expect(app.voice.microphoneUnavailable, isFalse);
      }

      final afterResume = serviceStopExpected || permissionRevokeExpected
          ? null
          : (await tester.runAsync(readPublisherStats))!;

      final voicePhaseAfterResume = app.voicePhase.name;
      final applicationSocketConnectedAfterResume = app.realtime.connected;
      final microphoneForegroundServiceActiveAfterResume =
          app.voice.microphoneForeground.active;
      final microphoneUnavailableAfterResume = app.voice.microphoneUnavailable;
      final microphoneMutedAfterResume = app.voice.microphoneMuted;
      final errorAfterResume = app.error == null ? null : 'present';
      Map<String, Object?>? microphoneRetryAfterServiceStop;

      await tester.pumpAndSettle();

      if (serviceStopExpected) {
        final drawerScrim = find.bySemanticsLabel('Закрыть панель');
        if (drawerScrim.evaluate().isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
        expect(find.byTooltip('Закрыть навигацию').hitTestable(), findsNothing);
        final retryNotice = find.byTooltip('Повторить включение микрофона');
        expect(retryNotice, findsOneWidget);
        final retryButton = find.widgetWithText(TextButton, 'Повторить');
        expect(retryButton, findsOneWidget);
        await tester.ensureVisible(retryButton);
        await tester.pumpAndSettle();

        final publisherBeforeRetry = (await tester.runAsync(
          readPublisherStats,
        ))!;
        final retryStartedAtUnixMs = DateTime.now()
            .toUtc()
            .millisecondsSinceEpoch;
        await tester.tap(retryButton);
        await waitFor(
          tester,
          () =>
              identical(app.room, initialRoom) &&
              app.voicePhase == VoicePhase.connected &&
              app.realtime.connected &&
              app.voice.microphoneForeground.active &&
              !app.voice.microphoneMuted &&
              !app.voice.microphoneUnavailable &&
              initialRoom.localParticipant!.audioTrackPublications.any(
                (publication) =>
                    publication.track != null && !publication.muted,
              ),
        );
        final publisherAfterRetry = (await tester.runAsync(
          waitForForegroundPublisherUplink,
        ))!;
        expect(publisherAfterRetry['microphoneTrackEnabled'], isTrue);
        expect(
          publisherAfterRetry['packetsSent'],
          greaterThan(publisherBeforeRetry['packetsSent'] as int),
        );
        expect(
          publisherAfterRetry['bytesSent'],
          greaterThan(publisherBeforeRetry['bytesSent'] as int),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 5)),
        );
        await tester.pumpAndSettle();
        microphoneRetryAfterServiceStop = {
          'status': 'PASS_SCOPED',
          'retryStartedAtUnixMs': retryStartedAtUnixMs,
          'retryNoticeUnobscured': true,
          'sameRoomAfterRetry': identical(app.room, initialRoom),
          'voicePhaseAfterRetry': app.voicePhase.name,
          'applicationSocketConnectedAfterRetry': app.realtime.connected,
          'microphoneForegroundServiceActiveAfterRetry':
              app.voice.microphoneForeground.active,
          'microphoneMutedAfterRetry': app.voice.microphoneMuted,
          'microphoneUnavailableAfterRetry': app.voice.microphoneUnavailable,
          'publisherBeforeRetry': publisherBeforeRetry,
          'publisherAfterRetry': publisherAfterRetry,
        };
      }

      final result = {
        'status': 'PASS_SCOPED',
        'voicePhase': voicePhaseAfterResume,
        'applicationSocketConnected': applicationSocketConnectedAfterResume,
        'microphoneForegroundServiceActiveAfterResume':
            microphoneForegroundServiceActiveAfterResume,
        'sameRoomObjectAfterResume': identical(app.room, initialRoom),
        'microphoneUnavailableAfterResume': microphoneUnavailableAfterResume,
        'microphoneMutedAfterResume': microphoneMutedAfterResume,
        'errorAfterResume': errorAfterResume,
        'sameMicrophoneTrackAfterResume': initialRoom
            .localParticipant!
            .audioTrackPublications
            .any(
              (publication) =>
                  publication.track?.mediaStreamTrack.id == initialTrackId,
            ),
        'backgroundSecondsObserved': backgroundSeconds,
        'backgroundStartedUnixMs': backgroundStartedUnixMs,
        'backgroundEndedUnixMs': backgroundEndedUnixMs,
        'microphoneServiceSamples': serviceSamples,
        'publisherBeforeBackground': before,
        'publisherAfterResume': afterResume,
        'microphoneRetryAfterServiceStop': microphoneRetryAfterServiceStop,
        'receiverValidation': serviceStopExpected
            ? 'independent receiver samples span explicit FGS stop; RTP advancement is checked across the whole interval'
            : permissionRevokeExpected
            ? 'independent receiver samples span RECORD_AUDIO revoke; RTP advancement is checked across the whole interval'
            : 'runner verifies independent inbound RTP counters during the background interval',
      };
      await control.writeAsString(
        jsonEncode({'status': 'complete', 'result': result}),
      );
      var acknowledged = false;
      for (var attempt = 0; attempt < 120; attempt++) {
        final command =
            jsonDecode(await control.readAsString()) as Map<String, dynamic>;
        if (command['status'] == 'acknowledged') {
          acknowledged = true;
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      expect(
        acknowledged,
        isTrue,
        reason: 'runner did not collect receiver RTP counters',
      );

      await tester.runAsync(app.leaveVoice);
      await waitFor(
        tester,
        () => app.voicePhase == VoicePhase.idle && app.room == null,
      );
    },
  );
}
