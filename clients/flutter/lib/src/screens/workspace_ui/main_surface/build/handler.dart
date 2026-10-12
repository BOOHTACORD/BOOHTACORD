import 'colored_box/handler.dart';
import '../../audio_settings_screen/component.dart';
import '../../direct_conversation/component.dart';
import '../../header/component.dart';
import '../../search_message_context/component.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMainSurfaceBuildBinding on WorkspaceMainSurfaceContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceMainSurfaceBuild(context);
  }
}

extension WorkspaceMainSurfaceBuildAction on WorkspaceMainSurfaceContext {
  Widget executeWorkspaceMainSurfaceBuild(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    void leaveWorkspacePanel() {
      state.toggleWorkspacePanel(WorkspacePanel.none);
    }

    if (state.workspacePanel == WorkspacePanel.searchContext) {
      return WorkspaceSearchMessageContext(state: state);
    }
    if (state.workspacePanel == WorkspacePanel.profile) {
      return ProfileScreen(
        state: state,
        onToggleNavigation: onToggleNavigation,
        onBack: compact ? leaveWorkspacePanel : null,
        onClose: leaveWorkspacePanel,
      );
    }
    if (state.workspacePanel == WorkspacePanel.audio) {
      return WorkspaceAudioSettingsScreen(
        state: state,
        onBack: leaveWorkspacePanel,
        onCapturePttKey: onCapturePttKey,
        capturingPttKey: capturingPttKey,
        onCaptureVoiceShortcut: onCaptureVoiceShortcut,
        capturingVoiceShortcut: capturingVoiceShortcut,
        hardwareKeyboardAvailable: hardwareKeyboardAvailable,
      );
    }
    if (state.workspacePanel == WorkspacePanel.admin &&
        state.user?.isAdmin == true) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) leaveWorkspacePanel();
        },
        child: AdminScreen(
          state: state,
          onToggleNavigation: onToggleNavigation,
          onClose: leaveWorkspacePanel,
        ),
      );
    }
    final direct = state.selectedDirectMessage;
    if (direct != null) {
      return ColoredBox(
        color: GcColors.content,
        child: WorkspaceDirectConversation(
          state: state,
          conversation: direct,
          onToggleNavigation: onToggleNavigation,
          onOpenMembers: onOpenMembers,
        ),
      );
    }
    final channel = state.selectedChannel;
    if (channel == null) {
      return Column(
        children: [
          WorkspaceHeader(
            icon: Icons.forum_outlined,
            title: state.guildProfile.name,
            subtitle: 'Выберите канал',
            onToggleNavigation: onToggleNavigation,
            onOpenMembers: onOpenMembers,
          ),
          const Expanded(
            child: ColoredBox(
              color: GcColors.content,
              child: Center(
                child: Text(
                  'Выберите канал',
                  style: TextStyle(color: GcColors.muted),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return renderMainSurfaceColoredBox(channel);
  }
}
