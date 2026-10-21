import '../scope_picker/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelSearchInputRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  Container renderWorkspaceSearchPanelSearchInput(
    double horizontalPadding,
    bool compact,
    Semantics scopeField,
  ) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
    ),
    padding: EdgeInsets.fromLTRB(
      horizontalPadding,
      0,
      horizontalPadding,
      compact ? 16 : 20,
    ),
    child: Column(
      children: [
        renderWorkspaceSearchPanelScopePicker(compact),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(child: scopeField),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey('workspace-search-submit'),
                onPressed: workspaceCanSubmit ? () => workspaceSearch() : null,
                child: const Text('Найти'),
              ),
            ],
          ),
        ),
        if (!compact &&
            switch (defaultTargetPlatform) {
              TargetPlatform.macOS ||
              TargetPlatform.windows ||
              TargetPlatform.linux => true,
              _ => false,
            })
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Enter — найти',
                key: ValueKey('workspace-search-enter-hint'),
                style: TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            ),
          ),
      ],
    ),
  );
}
