import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/voice/roster_state/phase.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/members_panel/component.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uiux_2026/capture_support.dart';

void main() {
  testWidgets(
    'shows the current voice channel and switches to the stream icon',
    (tester) async {
      await loadUiuxVisualCaptureFonts();
      final semantics = tester.ensureSemantics();
      final state = AppState(ApiClient())
        ..members = const [
          GuildMember(
            id: 'account-2',
            login: 'mika',
            displayName: 'Мика',
            role: 'MEMBER',
            presence: MemberPresence.online,
          ),
        ]
        ..topology = const ChannelTopology(
          revision: 1,
          categories: [
            ChannelCategory(
              id: 'category-1',
              name: 'Голосовые комнаты',
              channels: [
                GuildChannel(
                  id: 'voice-1',
                  name: 'Комната Секрет',
                  kind: ChannelKind.voice,
                  admissionClosed: false,
                ),
                GuildChannel(
                  id: 'voice-2',
                  name: 'Другая комната',
                  kind: ChannelKind.voice,
                  admissionClosed: false,
                ),
              ],
            ),
          ],
        )
        ..voiceRosters = const [
          VoiceRoomRoster(
            channelId: 'voice-1',
            participants: [
              VoiceRosterMember(
                accountId: 'account-2',
                displayName: 'Мика',
                screenSharing: false,
                microphoneMuted: false,
              ),
            ],
          ),
        ];
      state.voiceRoster.phase = VoiceRosterPhase.fresh;

      await tester.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('member-voice-presence-capture'),
                child: SizedBox(
                  width: 232,
                  height: 600,
                  child: WorkspaceMembersPanel(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Комната Секрет'), findsOneWidget);
      final voiceCaptionFinder = find.byKey(
        const ValueKey('member-voice-presence:account-2'),
      );
      expect(tester.widget<Text>(voiceCaptionFinder).maxLines, 2);
      final voiceCaption = tester.renderObject<RenderParagraph>(
        voiceCaptionFinder,
      );
      expect(
        voiceCaption.didExceedMaxLines,
        isFalse,
        reason: 'the voice channel caption should wrap instead of clipping',
      );
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(
        find.byTooltip('В голосовом канале «Комната Секрет»'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.text('Мика')).semanticsLabel,
        'Мика, В сети, в голосовом канале «Комната Секрет»',
      );
      await captureUiuxBoundary(
        tester,
        find.byKey(const ValueKey('member-voice-presence-capture')),
        fileName: 'guild-member-voice-channel.png',
        pixelRatio: 1,
      );

      state.voiceRosters = const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Мика',
              screenSharing: true,
              microphoneMuted: false,
            ),
          ],
        ),
      ];
      state.voiceRoster.changed();
      await tester.pumpAndSettle();

      expect(find.text('Комната Секрет'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(find.byIcon(Icons.desktop_windows_outlined), findsOneWidget);
      expect(
        find.byTooltip('Транслирует экран в канале «Комната Секрет»'),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.text('Мика')).semanticsLabel,
        'Мика, В сети, в голосовом канале «Комната Секрет», транслирует экран',
      );
      await captureUiuxBoundary(
        tester,
        find.byKey(const ValueKey('member-voice-presence-capture')),
        fileName: 'guild-member-screen-sharing.png',
        pixelRatio: 1,
      );

      state.voiceRosters = const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Мика',
              screenSharing: true,
              microphoneMuted: false,
            ),
          ],
        ),
        VoiceRoomRoster(
          channelId: 'voice-2',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Мика',
              screenSharing: false,
              microphoneMuted: false,
            ),
          ],
        ),
      ];
      state.voiceRoster.changed();
      await tester.pumpAndSettle();

      expect(find.text('Комната Секрет'), findsNothing);
      expect(find.byIcon(Icons.desktop_windows_outlined), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);

      state.voiceRosters = const [
        VoiceRoomRoster(
          channelId: 'voice-1',
          participants: [
            VoiceRosterMember(
              accountId: 'account-2',
              displayName: 'Мика',
              screenSharing: true,
              microphoneMuted: false,
            ),
          ],
        ),
      ];
      state.voiceRoster.changed();
      await tester.pumpAndSettle();

      state.voiceRoster.phase = VoiceRosterPhase.stale;
      state.voiceRoster.changed();
      await tester.pumpAndSettle();

      expect(find.text('Комната Секрет'), findsNothing);
      expect(find.byIcon(Icons.desktop_windows_outlined), findsNothing);

      state.voiceRoster.phase = VoiceRosterPhase.unavailable;
      state.voiceRoster.changed();
      await tester.pumpAndSettle();
      expect(find.text('Комната Секрет'), findsNothing);

      state
        ..voiceRosters = const [
          VoiceRoomRoster(channelId: 'voice-1', participants: []),
        ]
        ..voiceRoster.phase = VoiceRosterPhase.fresh;
      state.voiceRoster.changed();
      await tester.pumpAndSettle();

      expect(find.text('Комната Секрет'), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      semantics.dispose();
    },
  );
}
