import '../../native_bindings.dart';

import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceVoiceRoom extends StatefulWidget {
  const WorkspaceVoiceRoom({
    super.key,
    required this.state,
    required this.channel,
    required this.selectedScreenIdentity,
    required this.onSelectScreen,
    required this.pinnedMiniVisible,
    required this.fullscreenSelection,
    required this.onFullscreenSelectionChanged,
    required this.pinnedScreenIdentity,
    this.onToggleNavigation,
    this.onOpenMembers,
  });
  final AppState state;
  final GuildChannel channel;
  final String? selectedScreenIdentity;
  final ValueChanged<String?> onSelectScreen;
  final bool pinnedMiniVisible;
  final ScreenFullscreenSelection? fullscreenSelection;
  final ValueChanged<ScreenFullscreenSelection?> onFullscreenSelectionChanged;
  final String? pinnedScreenIdentity;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;

  @override
  State<WorkspaceVoiceRoom> createState() => WorkspaceVoiceRoomState();
}

class WorkspaceVoiceRoomState extends WorkspaceVoiceRoomStateContext
    with
        WorkspaceVoiceRoomStateBuildBinding,
        WorkspaceVoiceRoomStateWorkspaceToggleLocalScreenShareBinding,
        WorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreenBinding {}
