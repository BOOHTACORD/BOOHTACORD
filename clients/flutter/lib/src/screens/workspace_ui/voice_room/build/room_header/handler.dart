import '../../../header/component.dart';
import '../../../show_screen_share_setup/component.dart';
import '../header_actions/component.dart';
import '../../../voice_prejoin_header_subtitle/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceRoomRoomHeaderRenderer on WorkspaceVoiceRoomStateContext {
  WorkspaceHeader renderVoiceRoomRoomHeader(
    GuildChannel channel,
    String? selectedName,
    bool active,
    AppState state,
    int participantCount,
    BuildContext context,
  ) => WorkspaceHeader(
    icon: Icons.volume_up_outlined,
    title: channel.name,
    mobileConversationLayout: true,
    hideSubtitleOnCompact: true,
    onToggleNavigation: widget.onToggleNavigation,
    onOpenMembers: null,
    subtitle: selectedName != null
        ? 'Демонстрация $selectedName'
        : active
        ? state.voicePhase == VoicePhase.reconnecting
              ? 'Восстанавливаем связь · состояние микрофона сохранено'
              : 'Голосовой канал · участников: $participantCount'
        : workspaceVoicePrejoinHeaderSubtitle(state, channel),
    trailing: VoiceRoomHeaderActions(
      compact: MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint,
      onSearch: widget.onSearch,
      onOpenMembers: widget.onOpenMembers,
      sharing: state.screenSharePhase == ScreenSharePhase.sharing,
      shareBusy:
          state.screenSharePhase == ScreenSharePhase.starting ||
          state.screenSharePhase == ScreenSharePhase.stopping,
      onConfigureShare:
          active && state.screenSharePhase == ScreenSharePhase.sharing
          ? () => unawaited(workspaceShowScreenShareSetup(context, state))
          : null,
      onToggleShare: active
          ? switch (state.screenSharePhase) {
              ScreenSharePhase.starting || ScreenSharePhase.stopping => null,
              ScreenSharePhase.sharing => state.stopScreenShare,
              _ => () => unawaited(workspaceToggleLocalScreenShare(state)),
            }
          : null,
    ),
  );
}
