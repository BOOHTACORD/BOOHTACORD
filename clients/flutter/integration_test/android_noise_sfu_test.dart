import 'dart:io';

import 'package:boohtacord_desktop/src/app.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/audio_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'android_noise_sfu_support.dart';
import 'issue689_support.dart';
import 'issue689_voice_fixture.dart';
import 'local_qa_test.dart' show QaTls;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android RNNoise processes microphone frames in a real SFU room',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      const origin = String.fromEnvironment('QA_API_BASE');
      const pin = String.fromEnvironment('QA_CERT_SHA256');
      const password = String.fromEnvironment('QA_PASSWORD');
      if (origin != 'https://localhost:4810/api/v1' ||
          pin.length != 64 ||
          password.isEmpty) {
        throw StateError(
          'Owned QA endpoint and disposable credentials required',
        );
      }
      HttpOverrides.global = QaTls(pin);
      addTearDown(() => HttpOverrides.global = null);
      await tester.runAsync(
        () => rtc.WebRTC.initialize(
          options: {'androidUseHardwareNoiseSuppression': false},
        ),
      );
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
      await tester.runAsync(
        () => app.setAudioProcessing(
          app.audioProcessing.copyWith(
            noiseSuppressionMode: NoiseSuppressionMode.rnnoise,
          ),
        ),
      );
      final channel = await createVoiceFixture(
        tester,
        api,
        app,
        categoryName: 'Noise QA',
        channelName: 'Noise voice',
      );
      await tester.runAsync(() => app.joinVoice(channel));
      await waitFor(
        tester,
        () => app.noiseSuppressionRuntime.status == 'active',
      );
      final state = app.noiseSuppressionRuntime;
      expect(state.effectiveMode, 'rnnoise');
      expect(state.processedFrames, greaterThan(0));
      expect(state.sampleRate, 16000);
      expect(state.failureReason, isEmpty);
      expect(app.voice.microphoneUnavailable, isFalse);
      await verifyContinuedNoise(tester, app);
      await openAudioSettings(tester, app);
      final audioList = find.byKey(const ValueKey('audio-settings-list'));
      await waitFor(tester, () => audioList.evaluate().isNotEmpty);
      final scrollable = find.descendant(
        of: audioList,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('RNNoise активен'),
        120,
        scrollable: scrollable,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('RNNoise активен')),
        alignment: .4,
      );
      await tester.pumpAndSettle();
      expect(find.text('RNNoise активен'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('android-rnnoise-active');
      await tester.runAsync(app.leaveVoice);
      await tester.runAsync(app.logout);
      expect(tester.takeException(), isNull);
    },
  );
}
