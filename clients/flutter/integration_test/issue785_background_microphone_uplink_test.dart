import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
      expect(backgroundSeconds, greaterThanOrEqualTo(120));
      expect(serviceSamples.length, greaterThanOrEqualTo(5));
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

      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot(
        'issue785-flutter-microphone-after-background',
      );
      final result = {
        'status': 'PASS_SCOPED',
        'voicePhase': app.voicePhase.name,
        'applicationSocketConnected': app.realtime.connected,
        'microphoneForegroundServiceActiveAfterResume':
            app.voice.microphoneForeground.active,
        'sameRoomObjectAfterResume': identical(app.room, initialRoom),
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
        'receiverValidation': 'runner verifies independent inbound RTP counters during the background interval',
        'screenshot': 'issue785-flutter-microphone-after-background',
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
      await tester.runAsync(app.session.logout);
      await waitFor(tester, () => app.phase == AppPhase.signedOut);
      expect(tester.takeException(), isNull);
    },
  );
}
