import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension CategoryCategoryHeaderRenderer on WorkspaceCategoryStateContext {
  FocusableActionDetector renderCategoryCategoryHeader(
    ChannelCategory category,
    String disclosureLabel,
    AppState state,
  ) {
    final actionsVisible =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        workspaceHovered ||
        workspaceFocused;
    return FocusableActionDetector(
      key: ValueKey('workspace-category-focus:${category.id}'),
      onShowHoverHighlight: (value) =>
          workspaceMutateView(() => workspaceHovered = value),
      onShowFocusHighlight: (value) =>
          workspaceMutateView(() => workspaceFocused = value),
      child: Container(
        key: ValueKey('workspace-category-header:${category.id}'),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(GcRadii.md),
          child: SizedBox(
            height: GcLayout.channelRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    toggled: workspaceExpanded,
                    label: disclosureLabel,
                    child: InkWell(
                      key: ValueKey('workspace-category-toggle:${category.id}'),
                      onTap: () => workspaceMutateView(
                        () => workspaceExpanded = !workspaceExpanded,
                      ),
                      borderRadius: BorderRadius.circular(GcRadii.md),
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      mouseCursor: WidgetStateMouseCursor.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? SystemMouseCursors.click
                            : SystemMouseCursors.basic,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Icon(
                              workspaceExpanded
                                  ? Icons.expand_more_rounded
                                  : Icons.chevron_right_rounded,
                              size: 18,
                              color: GcColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                category.name,
                                style: const TextStyle(
                                  color: GcColors.text,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .6,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Visibility(
                  key: ValueKey('category-create-visibility:${category.id}'),
                  visible: actionsVisible,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TopologyCreateButton(state: state, category: category),
                ),
                TopologyObjectMenu(
                  state: state,
                  target: category,
                  visible: actionsVisible,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
