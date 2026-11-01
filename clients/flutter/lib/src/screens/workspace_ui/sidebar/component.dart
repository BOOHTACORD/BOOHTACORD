import '../channel_navigation/component.dart';
import '../connection_status/component.dart';
import '../direct_message_navigation/component.dart';
import '../user_footer/component.dart';
import '../voice_dock/component.dart';
import '../../../features/realtime/lifecycle/controller.dart';
import '../native_bindings.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.state,
    this.showVoiceDock = true,
    this.onChannelSelected,
    this.onClose,
    this.onSearch,
    this.searchFocusNode,
  });
  final AppState state;
  final bool showVoiceDock;
  final VoidCallback? onChannelSelected;
  final VoidCallback? onClose;
  final VoidCallback? onSearch;
  final FocusNode? searchFocusNode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final compactFooter = constraints.maxHeight < 520 && textScale >= 1.5;
      return ColoredBox(
        color: GcColors.sidebar,
        child: Column(
          children: [
            WorkspaceNavigationTop(
              guildName: state.guildProfile.name,
              memberCount: state.members.isEmpty ? null : state.members.length,
              channelsSelected:
                  state.navigationSection == NavigationSection.channels,
              onSearch: onSearch ?? state.openSearchPanel,
              onChannels: state.showChannels,
              onDirectMessages: state.showDirectMessages,
              onClose: onClose,
              searchFocusNode: searchFocusNode,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: state.refreshTopology,
                child: ListView(
                  key: const ValueKey('workspace-channel-scroll-area'),
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        state,
                        state.realtime,
                        state.voiceRoster,
                      ]),
                      builder: (context, _) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: WorkspaceConnectionStatus(
                          chatConnected: state.realtime.connected,
                          chatConnecting:
                              state.realtime.connecting ||
                              state.realtime.socket != null,
                          voicePhase: state.voicePhase,
                          rosterPhase: state.voiceRoster.phase,
                          rosterRetained: state.voiceRoster.voiceRosters != null,
                          lastUpdatedAt: state.voiceRoster.lastUpdatedAt,
                          rosterCanRetry: state.voiceRoster.canRetry,
                          onRetryChat: state.realtime.retryNow,
                          onRetryRoster: () => state.refreshVoiceRosters(),
                        ),
                      ),
                    ),
                    if (state.topology == null)
                      const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (state.navigationSection ==
                                NavigationSection.channels)
                              WorkspaceChannelNavigation(
                                state: state,
                                onChannelSelected: onChannelSelected,
                              )
                            else
                              WorkspaceDirectMessageNavigation(
                                state: state,
                                onSelected: onChannelSelected,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showVoiceDock && state.voiceChannel != null)
              WorkspaceVoiceDock(state: state),
            const Divider(height: 1),
            WorkspaceUserFooter(
              state: state,
              onNavigate: onClose,
              compact: compactFooter,
            ),
          ],
        ),
      );
    },
  );
}
