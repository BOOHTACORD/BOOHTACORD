import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceSearchPanelScopeFieldRenderer
    on WorkspaceWorkspaceSearchPanelStateContext {
  Semantics renderWorkspaceSearchPanelScopeField(
    ({bool direct, String id, String label})? current,
  ) => Semantics(
    label: 'Область поиска',
    child: DropdownButtonFormField<String>(
      key: const ValueKey('workspace-search-scope'),
      initialValue: workspaceScope,
      isDense: true,
      isExpanded: true,
      icon: const Icon(
        Icons.expand_more_rounded,
        color: GcColors.muted,
        size: 16,
      ),
      alignment: AlignmentDirectional.centerStart,
      dropdownColor: GcColors.raised,
      style: const TextStyle(
        fontFamily: 'Inter',
        color: GcColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: GcColors.raised,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(10, 0, 8, 0),
        constraints: switch (Theme.of(context).platform) {
          TargetPlatform.android ||
          TargetPlatform.iOS => const BoxConstraints(minHeight: 48),
          _ => const BoxConstraints.tightFor(height: 32),
        },
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
          borderSide: const BorderSide(color: GcColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
          borderSide: const BorderSide(color: GcColors.focus),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GcRadii.md),
          borderSide: const BorderSide(color: GcColors.borderSubtle),
        ),
      ),
      selectedItemBuilder: (context) => [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text('Везде', maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (current != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              current.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      items: [
        const DropdownMenuItem(value: 'all', child: Text('Везде')),
        if (current != null)
          DropdownMenuItem(
            value: 'current',
            child: Text(current.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: workspaceLoading
          ? null
          : (value) {
              if (value == null) return;
              workspaceMutateView(() {
                workspaceScope = value;
                workspaceReset();
              });
            },
    ),
  );
}
