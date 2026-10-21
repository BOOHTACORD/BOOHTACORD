import '../category/component.dart';
import '../direct_message_navigation/component.dart';
import '../user_footer/component.dart';
import '../voice_dock/component.dart';
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
  Widget build(BuildContext context) => ColoredBox(
    color: GcColors.sidebar,
    child: Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: state.refreshTopology,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                WorkspaceNavigationTop(
                  guildName: state.guildProfile.name,
                  memberCount: state.members.isEmpty
                      ? null
                      : state.members.length,
                  channelsSelected:
                      state.navigationSection == NavigationSection.channels,
                  onSearch: onSearch ?? state.openSearchPanel,
                  onChannels: state.showChannels,
                  onDirectMessages: state.showDirectMessages,
                  onClose: onClose,
                  searchFocusNode: searchFocusNode,
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
                          Row(
                            children: [
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'КАНАЛЫ',
                                    style: TextStyle(
                                      color: GcColors.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              TopologyCreateButton(state: state),
                            ],
                          ),
                        if (state.navigationSection ==
                            NavigationSection.channels)
                          for (final category in state.topology!.categories)
                            WorkspaceCategory(
                              key: ValueKey(
                                'workspace-category:${category.id}',
                              ),
                              state: state,
                              category: category,
                              onChannelSelected: onChannelSelected,
                            )
                        else
                          WorkspaceDirectMessageNavigation(
                            state: state,
                            onSelected: onChannelSelected,
                          ),
                        if (state.navigationSection ==
                                NavigationSection.channels &&
                            state.topology!.categories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Каналы пока не созданы.',
                              style: TextStyle(color: GcColors.muted),
                            ),
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
        WorkspaceUserFooter(state: state, onNavigate: onClose),
      ],
    ),
  );
}
