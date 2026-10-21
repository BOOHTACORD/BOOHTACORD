import '../result_hit/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelResultsRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  Expanded renderWorkspaceSearchPanelResults(
    String emptyTitle,
    String emptyMessage,
    IconData emptyIcon,
  ) => Expanded(
    child: workspaceResults.isEmpty
        ? ExcludeSemantics(
            child: SearchPanelEmptyState(
              key: const ValueKey('workspace-search-empty-state'),
              title: emptyTitle,
              message: emptyMessage,
              loading: workspaceLoading,
              icon: emptyIcon,
            ),
          )
        : ListView.separated(
            controller: workspaceScroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount:
                workspaceResults.length + (workspaceNextCursor == null ? 0 : 1),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == workspaceResults.length) {
                return Center(
                  child: TextButton(
                    onPressed: !workspaceCanLoadMore
                        ? null
                        : () => workspaceSearch(before: workspaceNextCursor),
                    child: const Text('Показать ещё'),
                  ),
                );
              }
              final message = workspaceResults[index];
              final member = state.members
                  .where((value) => value.id == message.authorId)
                  .firstOrNull;
              final author = member?.displayName ?? message.authorId;
              return Semantics(
                button: true,
                label: 'Открыть сообщение от $author',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('search-result-${message.id}'),
                    onTap: () => state.openSearchContext(message),
                    borderRadius: BorderRadius.circular(GcRadii.md),
                    child: Ink(
                      decoration: BoxDecoration(color: Colors.transparent),
                      child: renderWorkspaceSearchPanelResultHit(
                        message,
                        author,
                        member,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
  );
}
