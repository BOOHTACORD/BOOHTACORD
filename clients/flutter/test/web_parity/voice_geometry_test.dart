import 'dart:collection';

import 'package:livekit_client/livekit_client.dart';
import 'package:livekit_client/src/proto/livekit_models.pb.dart' as lk;

import '../uiux_2026/capture_support.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:boohtacord_desktop/src/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_dock/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_room/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_participant_strip/component.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'voice dock keeps leave reachable on $platform at narrow width',
      (t) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final state = AppState(ApiClient())
          ..voicePhase = VoicePhase.connected
          ..voiceChannel = const GuildChannel(
            id: 'voice',
            name: 'Голос',
            kind: ChannelKind.voice,
            admissionClosed: false,
          );
        addTearDown(state.dispose);
        await t.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 240,
                  child: WorkspaceVoiceDock(
                    state: state,
                    compact: platform == TargetPlatform.android,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        expect(find.byTooltip('Ещё настройки голоса'), findsOneWidget);
        final leave = t.getRect(find.byTooltip('Выйти из голосового канала'));
        final dock = t.getRect(find.byType(WorkspaceVoiceDock));
        expect(leave.right, lessThanOrEqualTo(dock.right));
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
  testWidgets(
    'voice room removes duplicate welcome and cards grow for large text',
    (t) async {
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SizedBox(
                width: 320,
                height: 480,
                child: WorkspaceVoiceParticipantRoom(
                  state: state,
                  room: null,
                  participants: const [],
                  screens: const [],
                  onScreenSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Все в сборе'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('voice room places four participant cards in a desktop row', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1440, 900);
    addTearDown(t.view.reset);
    final room = _Room();
    final participants = <RemoteParticipant>[];
    for (var index = 1; index <= 4; index++) {
      // ignore: invalid_use_of_internal_member
      final created = await RemoteParticipant.createFromInfo(
        room: room,
        info: lk.ParticipantInfo(
          sid: 'sid-$index',
          identity: 'remote-$index',
          name: 'Участник $index',
          metadata: 'account:person-$index',
        ),
      );
      room.members[created.participant.identity] = created.participant;
      participants.add(created.participant);
    }
    final state = AppState(ApiClient())..voicePhase = VoicePhase.connected;
    addTearDown(state.dispose);

    await t.pumpWidget(
      MaterialApp(
        theme: guildTheme(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: WorkspaceVoiceParticipantRoom(
            state: state,
            room: room,
            participants: participants,
            screens: const [],
            onScreenSelected: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    final firstRow = [
      find.byKey(const ValueKey('voice-participant-card:self')),
      for (var index = 1; index <= 3; index++)
        find.byKey(ValueKey('voice-participant-card:sid-$index')),
    ].map(t.getRect).toList();
    final fifthCard = t.getRect(
      find.byKey(const ValueKey('voice-participant-card:sid-4')),
    );
    expect(firstRow.map((rect) => rect.top), everyElement(firstRow.first.top));
    expect(fifthCard.top, greaterThan(firstRow.first.bottom));
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(room.dispose);
  });
  testWidgets(
    'screen audience strip keeps large-text counts and watchers inside 92 dp',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 92);
      addTearDown(t.view.reset);
      final state = AppState(ApiClient());
      addTearDown(state.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: guildTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 92),
              textScaler: TextScaler.linear(2),
            ),
            child: Material(
              child: WorkspaceVoiceParticipantStrip(
                state: state,
                localName: 'Вы',
                localAvatarUrl: null,
                localMuted: false,
                localSpeaking: false,
                participants: const [],
                showAudience: true,
                watcherAccountIds: const ['one', 'two'],
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('screen-viewer-audience-count')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final count in [1, 5, 10]) {
    for (final width in [320.0, 768.0, 1440.0]) {
      testWidgets('voice $count participants at $width large text', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 480);
        addTearDown(t.view.reset);
        await loadUiuxVisualCaptureFonts();
        final room = _Room();
        final state = AppState(ApiClient())..voicePhase = VoicePhase.connected;
        addTearDown(state.dispose);
        for (var i = 1; i < count; i++) {
          // ignore: invalid_use_of_internal_member
          final created = await RemoteParticipant.createFromInfo(
            room: room,
            info: lk.ParticipantInfo(
              sid: 'sid-$i',
              identity: 'remote-$i',
              name: 'Очень длинное имя участника $i',
              metadata: 'account:person-$i',
              tracks: [
                lk.TrackInfo(
                  sid: 'screen-$i',
                  type: lk.TrackType.VIDEO,
                  source: lk.TrackSource.SCREEN_SHARE,
                  muted: false,
                ),
              ],
            ),
          );
          room.members[created.participant.identity] = created.participant;
        }
        state.voice.screenViewerAccountIds = const ['person-1'];
        final root = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: guildTheme(),
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 480),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(
                body: RepaintBoundary(
                  key: root,
                  child: WorkspaceVoiceParticipantRoom(
                    state: state,
                    room: room,
                    participants: room.members.values.toList(),
                    screens: const [],
                    onScreenSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('voice-participant-card:self')),
          findsOneWidget,
        );
        if (count > 1) expect(find.text('Смотрит трансляцию'), findsOneWidget);
        expect(t.takeException(), isNull);
        await captureUiuxBoundary(
          t,
          find.byKey(root),
          fileName: 'parity-voice-$count-${width.toInt()}x480-scale2.png',
          pixelRatio: 1,
        );
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(room.dispose);
      });
    }
  }
}

class _Room extends Room {
  final members = <String, RemoteParticipant>{};
  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView(members);
}
