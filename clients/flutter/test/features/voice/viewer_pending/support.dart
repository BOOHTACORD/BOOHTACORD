import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/features/voice/screen_viewer/publication_generation.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_room/component.dart';
import 'package:boohtacord_desktop/src/screens/workspace_ui/voice_room/build/ended_screen/handler.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';

class _Peer extends Fake implements RemoteParticipant {
  _Peer(this.identity);
  @override
  final String identity;
}

class _Publication extends Fake implements RemoteTrackPublication<RemoteTrack> {
  _Publication(this.sid, this.peer);
  final String peer;
  @override
  final String sid;
  @override
  RemoteParticipant get participant => _Peer(peer);
}

class _PendingRoom extends WorkspaceVoiceRoom {
  const _PendingRoom(AppState state, this.publication)
    : super(
        state: state,
        channel: const GuildChannel(
          id: 'qa-voice',
          name: 'SHARE_TEST',
          kind: ChannelKind.voice,
          admissionClosed: false,
        ),
        selectedScreenIdentity: 'qa-publisher',
        onSelectScreen: _select,
        pinnedMiniVisible: false,
        fullscreenSelection: null,
        onFullscreenSelectionChanged: _fullscreen,
        pinnedScreenIdentity: null,
      );
  final RemoteTrackPublication<RemoteTrack>? publication;
  static void _select(String? _) {}
  static void _fullscreen(dynamic _) {}
  @override
  WorkspaceVoiceRoomState createState() => _PendingState();
}

class _PendingState extends WorkspaceVoiceRoomState {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: renderVoiceRoomEndedScreen(
      (widget as _PendingRoom).publication,
      null,
      widget.state,
      null,
      const [],
      const [],
    ),
  );
}

Future<AppState> renderPending(
  WidgetTester tester, {
  bool published = true,
  bool exhausted = true,
  bool stale = false,
  bool otherParticipant = false,
  bool selectionMoved = false,
  bool inFlight = false,
}) async {
  final state = AppState(ApiClient());
  state.voice.selectedRemoteScreenViewerIdentity = selectionMoved
      ? 'qa-next'
      : 'qa-publisher';
  state.voice.selectedRemoteScreenViewerGeneration =
      const ScreenViewerPublicationGeneration(
        participantIdentity: 'qa-publisher',
        publicationSid: 'qa-publication',
      );
  state.voice.remoteScreenViewerRecoveryAttempt = exhausted ? 2 : 0;
  if (inFlight) {
    state.voice.remoteScreenViewerRecoveryInFlightGeneration =
        state.voice.selectedRemoteScreenViewerGeneration;
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: _PendingRoom(
        state,
        published
            ? _Publication(
                stale ? 'qa-replacement' : 'qa-publication',
                otherParticipant ? 'qa-other' : 'qa-publisher',
              )
            : null,
      ),
    ),
  );
  return state;
}
