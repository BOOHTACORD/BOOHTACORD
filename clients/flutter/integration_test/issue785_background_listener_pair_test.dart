import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/session/lifecycle/controller.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';
import 'package:boohtacord_desktop/src/models.dart';

import '../test/test_support/app_resume_wait.dart';
import 'issue689_support.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android listener receives paired audio after background resume',
    (tester) async {
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      const receiver = String.fromEnvironment('QA_PAIR_ACCOUNT');
      const channelId = String.fromEnvironment('QA_PAIR_CHANNEL_ID');
      if (origin != 'https://localhost:4810/api/v1' ||
          pin.length != 64 ||
          password.isEmpty ||
          receiver.isEmpty ||
          channelId.isEmpty ||
          !Platform.isAndroid) {
        throw StateError('Owned Android pair QA configuration required');
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
      await tester.enterText(fields.at(0), receiver);
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
      await tester.runAsync(() => app.joinVoice(channel, listenerOnly: true));
      await waitFor(
        tester,
        () => app.voicePhase == VoicePhase.listener && app.room != null,
      );
      await waitFor(
        tester,
        () => app.voiceRoster.phase == VoiceRosterPhase.fresh,
      );
      final initialRoom = app.room;
      expect(initialRoom, isNotNull);
      expect(app.room!.localParticipant!.audioTrackPublications, isEmpty);

      Future<Map<String, Object?>> readReceiverStats() async {
        final tracks = <RemoteAudioTrack>[];
        for (final participant in app.room!.remoteParticipants.values) {
          for (final publication in participant.audioTrackPublications) {
            final track = publication.track;
            if (publication.subscribed && track != null) tracks.add(track);
          }
        }
        var packets = 0;
        var bytes = 0;
        var samplesDuration = 0.0;
        var totalAudioEnergy = 0.0;
        for (final track in tracks) {
          final stats = await track.getReceiverStats();
          packets += stats?.packetsReceived?.toInt() ?? 0;
          bytes += stats?.bytesReceived?.toInt() ?? 0;
          samplesDuration += stats?.totalSamplesDuration?.toDouble() ?? 0;
          totalAudioEnergy += stats?.totalAudioEnergy?.toDouble() ?? 0;
        }
        return {
          'subscribedAudioTracks': tracks.length,
          'inboundAudioPackets': packets,
          'inboundAudioBytes': bytes,
          'totalSamplesDuration': samplesDuration,
          'totalAudioEnergy': totalAudioEnergy,
        };
      }

      Future<void> realDelay(Duration duration) async {
        await tester.runAsync(() => Future<void>.delayed(duration));
        await tester.pump();
      }

      Map<String, Object?> before = {};
      for (var attempt = 0; attempt < 50; attempt++) {
        before = (await tester.runAsync(readReceiverStats))!;
        if ((before['inboundAudioPackets'] as int) >= 10 &&
            (before['inboundAudioBytes'] as int) > 1000 &&
            (before['totalAudioEnergy'] as double) > 0) {
          break;
        }
        await realDelay(const Duration(milliseconds: 500));
      }
      expect(before['subscribedAudioTracks'], 1);
      expect((before['inboundAudioPackets'] as int), greaterThan(0));
      expect((before['inboundAudioBytes'] as int), greaterThan(0));
      expect((before['totalSamplesDuration'] as double), greaterThan(0));
      expect((before['totalAudioEnergy'] as double), greaterThan(0));

      final temporaryDirectory = await getTemporaryDirectory();
      final control = File(
        '${temporaryDirectory.path}/issue785_flutter_pair_control.json',
      );
      expect(await control.exists(), isFalse, reason: 'stale control file');
      final readyAt = DateTime.now().toUtc();
      await control.writeAsString(
        jsonEncode({'status': 'ready', 'receiverBeforeBackground': before}),
      );

      await tester.runAsync(
        () => waitForAppBackgroundThenResume(
          readLifecycleState: () => binding.lifecycleState,
          timeout: const Duration(minutes: 75),
          pollInterval: const Duration(seconds: 5),
        ),
      );
      final resumeCommand =
          jsonDecode(await control.readAsString()) as Map<String, dynamic>;
      expect(
        resumeCommand['status'],
        'resume',
        reason: 'runner must hand off resume before opening the Android app',
      );
      final backgroundSeconds =
          (resumeCommand['backgroundSecondsObserved'] as num).toDouble();
      final playbackServiceSamples =
          (resumeCommand['playbackServiceSamples'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(backgroundSeconds, greaterThanOrEqualTo(120));
      expect(playbackServiceSamples.length, greaterThanOrEqualTo(5));
      expect(
        playbackServiceSamples.every(
          (sample) =>
              sample['playback_foreground_service_active'] == true &&
              sample['microphone_foreground_service_active'] == false,
        ),
        isTrue,
        reason: 'playback FGS must remain active without microphone FGS in background',
      );

      await waitFor(
        tester,
        () =>
            app.room != null &&
            app.voicePhase == VoicePhase.listener &&
            app.realtime.connected,
      );
      expect(
        identical(app.room, initialRoom),
        isTrue,
        reason: 'background resume must retain one LiveKit Room instance',
      );
      final afterResume = (await tester.runAsync(readReceiverStats))!;
      final backgroundDecodedSampleDuration =
          (afterResume['totalSamplesDuration'] as double) -
          (before['totalSamplesDuration'] as double);
      expect(
        backgroundDecodedSampleDuration,
        greaterThanOrEqualTo(backgroundSeconds * 0.8),
        reason:
            'decoded remote audio must cover the Android background interval',
      );
      expect(
        app.voicePlaybackBackgroundUnavailable,
        isFalse,
        reason:
            'playback foreground coverage must remain available after resume',
      );
      var progressing = false;
      Map<String, Object?> progress = afterResume;
      for (var attempt = 0; attempt < 30; attempt++) {
        await realDelay(const Duration(milliseconds: 500));
        progress = (await tester.runAsync(readReceiverStats))!;
        if ((progress['inboundAudioPackets'] as int) >
                (afterResume['inboundAudioPackets'] as int) &&
            (progress['inboundAudioBytes'] as int) >
                (afterResume['inboundAudioBytes'] as int) &&
            (progress['totalSamplesDuration'] as double) >
                (afterResume['totalSamplesDuration'] as double)) {
          progressing = true;
          break;
        }
      }
      expect(
        progressing,
        isTrue,
        reason: 'paired receiver RTP did not advance',
      );

      final samples = <Map<String, Object?>>[progress];
      for (var sample = 0; sample < 3; sample++) {
        await realDelay(const Duration(seconds: 10));
        final current = (await tester.runAsync(readReceiverStats))!;
        expect(
          current['inboundAudioPackets'],
          greaterThan(samples.last['inboundAudioPackets'] as int),
          reason: 'receiver packets must advance in every post-resume interval',
        );
        expect(
          current['inboundAudioBytes'],
          greaterThan(samples.last['inboundAudioBytes'] as int),
          reason: 'receiver bytes must advance in every post-resume interval',
        );
        expect(
          current['totalSamplesDuration'],
          greaterThan(samples.last['totalSamplesDuration'] as double),
          reason: 'decoded audio sample duration must advance after resume',
        );
        expect(current['subscribedAudioTracks'], 1);
        samples.add(current);
      }

      final closeNavigation = find.byTooltip('Закрыть навигацию');
      if (closeNavigation.evaluate().isNotEmpty) {
        await tester.tap(closeNavigation.first);
        await tester.pumpAndSettle();
      }
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot(
        'issue785-flutter-listener-after-background',
      );
      final result = {
        'status': 'PASS_SCOPED',
        'voicePhase': app.voicePhase.name,
        'applicationSocketConnected': app.realtime.connected,
        'sameRoomObjectAfterResume': identical(app.room, initialRoom),
        'localAudioPublications':
            app.room!.localParticipant!.audioTrackPublications.length,
        'backgroundElapsedSeconds': DateTime.now()
            .toUtc()
            .difference(readyAt)
            .inSeconds,
        'receiverBeforeBackground': before,
        'receiverAtResume': afterResume,
        'backgroundSecondsObserved': backgroundSeconds,
        'backgroundDecodedSampleDurationSeconds':
            backgroundDecodedSampleDuration,
        'playbackServiceSamples': playbackServiceSamples,
        'receiverProgressingAfterResume': progress,
        'receiverSamples': samples,
        'audioEvidence': 'LiveKit receiver RTP and audio receiver statistics; emulator acoustic output was not measured',
        'screenshot': 'issue785-flutter-listener-after-background',
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
        await realDelay(const Duration(milliseconds: 250));
      }
      expect(
        acknowledged,
        isTrue,
        reason: 'runner did not collect receiver stats',
      );

      await tester.runAsync(app.leaveVoice);
      await waitFor(
        tester,
        () => app.voicePhase == VoicePhase.idle && app.room == null,
      );
      await tester.runAsync(app.session.logout);
      await waitFor(tester, () => app.phase == AppPhase.signedOut);
      expect(tester.takeException(), isNull);
    },
  );
}
