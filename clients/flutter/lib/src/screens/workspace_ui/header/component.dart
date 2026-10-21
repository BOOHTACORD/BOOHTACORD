import '../native_bindings.dart';

import 'dart:math' as math;

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onToggleNavigation,
    this.onOpenMembers,
    this.onBack,
    this.trailing,
    this.mobileConversationLayout = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onOpenMembers;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool mobileConversationLayout;
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    final compactConversation = compact && mobileConversationLayout;
    final headerButtonConstraints = BoxConstraints.tightFor(
      width: compact ? 44 : 48,
      height: compact ? 44 : 48,
    );
    final scaledHeaderTextHeight =
        MediaQuery.textScalerOf(context).scale(16) * 1.4 +
        MediaQuery.textScalerOf(context).scale(12) * 1.4;
    return SizedBox(
      key: const ValueKey('workspace-header'),
      height: math.max(
        compact ? GcLayout.headerMobileHeight : GcLayout.headerHeight,
        scaledHeaderTextHeight + 8,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GcColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Назад',
                  constraints: headerButtonConstraints,
                  padding: EdgeInsets.zero,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              if (onToggleNavigation != null) ...[
                IconButton(
                  tooltip: 'Открыть навигацию',
                  constraints: headerButtonConstraints,
                  padding: EdgeInsets.zero,
                  onPressed: onToggleNavigation,
                  icon: const Icon(Icons.menu),
                ),
                SizedBox(width: compact ? 8 : 4),
              ],
              if (!compactConversation) ...[
                Icon(icon, color: GcColors.muted),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: title,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GcColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (onOpenMembers != null)
                IconButton(
                  tooltip: 'Открыть участников',
                  constraints: headerButtonConstraints,
                  padding: EdgeInsets.zero,
                  onPressed: onOpenMembers,
                  icon: const Icon(Icons.people_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
