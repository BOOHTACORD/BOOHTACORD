import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MembersPanelMemberGroupsRenderer
    on WorkspaceMembersPanelStateContext {
  Widget renderMembersPanelMemberGroups(
    List<({List<GuildMember> members, String title})> groups,
    BuildContext context,
  ) {
    final visibleGroups = groups
        .where((group) => group.members.isNotEmpty)
        .toList();
    return Expanded(
      child: RefreshIndicator(
        onRefresh: state.refreshMembers,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (state.membersError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.membersError!,
                        style: const TextStyle(color: GcColors.danger),
                      ),
                    ),
                    TextButton(
                      onPressed: state.membersLoading
                          ? null
                          : state.refreshMembers,
                      child: Text(
                        state.membersLoading ? 'Загружаем…' : 'Повторить',
                      ),
                    ),
                  ],
                ),
              )
            else if (state.membersLoading && state.members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Загружаем участников…',
                  style: TextStyle(color: GcColors.muted),
                ),
              )
            else if (state.members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'В гильдии пока нет участников.',
                  style: TextStyle(color: GcColors.muted),
                ),
              ),
            for (final (index, group) in visibleGroups.indexed) ...[
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    '${group.title.toUpperCase()} — ${group.members.length}',
                    style: const TextStyle(
                      color: GcColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: .4,
                    ),
                  ),
                ),
              ),
              for (final (memberIndex, member) in group.members.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: memberIndex + 1 < group.members.length ? 2 : 0,
                  ),
                  child: workspaceMemberRow(context, member),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
