import 'package:boohtacord_desktop/src/app_state.dart';
import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

AppState shortEditorState({ApiClient? api}) {
  final state = AppState(api ?? ApiClient());
  const dm = DirectConversation(
    id: 'qa-dm',
    participantId: 'qa-peer',
    displayName: 'QA peer',
    unreadCount: 0,
  );
  state.user = const SessionUser(accountId: 'qa-self', role: 'MEMBER');
  state.phase = AppPhase.ready;
  state.topology = const ChannelTopology(revision: 1, categories: []);
  state.directMessages = [dm];
  state.selectedDirectMessage = dm;
  state.voiceChannel = const GuildChannel(
    id: 'qa-voice',
    name: 'SHARE_TEST',
    kind: ChannelKind.voice,
    admissionClosed: false,
  );
  state.voicePhase = VoicePhase.connected;
  state.realtime.attempt = 1;
  return state;
}
