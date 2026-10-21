import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_strip/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'uiux_2026/capture_support.dart';

class _Participant extends Fake implements RemoteParticipant {
  _Participant(this.name, this.accountId);

  @override
  final String name;

  final String accountId;

  @override
  String get metadata => 'account:$accountId';

  @override
  bool get isSpeaking => false;

  @override
  List<RemoteTrackPublication<RemoteAudioTrack>> get audioTrackPublications =>
      const [];

  @override
  List<RemoteTrackPublication<RemoteVideoTrack>> get videoTrackPublications =>
      const [];
}

void main() {
  testWidgets('shows the selected stream audience and marks its watchers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 92);
    addTearDown(tester.view.reset);
    await loadUiuxVisualCaptureFonts();
    if (!uiuxVisualCaptureEnabled) {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
    }

    final state = AppState(ApiClient())
      ..user = const SessionUser(
        accountId: '11111111-1111-4111-8111-111111111111',
        role: 'MEMBER',
      );
    addTearDown(state.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        home: Material(
          color: GcColors.sidebar,
          child: DefaultTextStyle(
            style: guildTheme().textTheme.bodyMedium!,
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const ValueKey('screen-audience-capture'),
                child: WorkspaceVoiceParticipantStrip(
                  state: state,
                  localName: 'Вы',
                  localAvatarUrl: null,
                  localMuted: false,
                  localSpeaking: false,
                  participants: [
                    _Participant(
                      'Зритель',
                      '22222222-2222-4222-8222-222222222222',
                    ),
                  ],
                  showAudience: true,
                  watcherAccountIds: const [
                    '11111111-1111-4111-8111-111111111111',
                    '22222222-2222-4222-8222-222222222222',
                  ],
                  watcherLabel: 'Смотрит эту трансляцию',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Зрители · 2'), findsOneWidget);
    expect(find.byTooltip('Смотрит эту трансляцию'), findsNWidgets(2));
    await captureUiuxBoundary(
      tester,
      find.byKey(const ValueKey('screen-audience-capture')),
      fileName: 'flutter-screen-audience-viewer-strip-1024x92@2x.png',
      pixelRatio: 2,
    );
  });

  testWidgets(
    'does not show audience when no stream is selected or published',
    (tester) async {
      final state = AppState(ApiClient());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: Scaffold(
            body: WorkspaceVoiceParticipantStrip(
              state: state,
              localName: 'Вы',
              localAvatarUrl: null,
              localMuted: false,
              localSpeaking: false,
              participants: const [],
            ),
          ),
        ),
      );

      expect(find.textContaining('Зрители'), findsNothing);
      expect(find.byTooltip('Смотрит вашу трансляцию'), findsNothing);
      expect(find.byTooltip('Смотрит эту трансляцию'), findsNothing);
    },
  );
}
