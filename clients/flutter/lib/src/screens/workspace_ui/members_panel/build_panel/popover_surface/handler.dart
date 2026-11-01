import '../member_groups/handler.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension MembersPanelPopoverSurfaceRenderer
    on WorkspaceMembersPanelStateContext {
  ColoredBox renderMembersPanelPopoverSurface(
    List<({List<GuildMember> members, String title})> groups,
    BuildContext context,
  ) => ColoredBox(
    color: GcColors.sidebar,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          key: const ValueKey('members-panel'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                key: ValueKey('members-panel-heading'),
                header: true,
                label: 'УЧАСТНИКИ',
                child: SizedBox.shrink(),
              ),
              renderMembersPanelMemberGroups(groups, context),
            ],
          ),
        ),
        if (onClose != null)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Закрыть участников',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    ),
  );
}
