import '../../../conversation/component.dart';
import '../../../voice_room/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MainSurfaceColoredBoxRenderer on WorkspaceMainSurfaceContext {
  ColoredBox renderMainSurfaceColoredBox(GuildChannel channel) => ColoredBox(
    color: GcColors.content,
    child: channel.kind == ChannelKind.text
        ? WorkspaceConversation(
            state: state,
            channel: channel,
            onToggleNavigation: onToggleNavigation,
            onOpenMembers: onOpenMembers,
          )
        : WorkspaceVoiceRoom(
            key: ValueKey('voice-room:${channel.id}'),
            state: state,
            channel: channel,
            selectedScreenIdentity: selectedScreenIdentity,
            onSelectScreen: onSelectScreen,
            pinnedMiniVisible: pinnedMiniVisible,
            fullscreenSelection: fullscreenSelection,
            onFullscreenSelectionChanged: onFullscreenSelectionChanged,
            pinnedScreenIdentity: pinnedScreenIdentity,
            onToggleNavigation: onToggleNavigation,
            onOpenMembers: onOpenMembers,
          ),
  );
}
