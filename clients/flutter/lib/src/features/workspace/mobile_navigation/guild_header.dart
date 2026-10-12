import 'package:flutter/material.dart';

import '../../../theme.dart';
import 'guild_mark.dart';
import '../../guild/profile/name.dart';

class WorkspaceGuildHeader extends StatelessWidget {
  const WorkspaceGuildHeader({
    super.key,
    required this.guildName,
    required this.compact,
    this.memberCount,
    this.onClose,
  });

  final String guildName;
  final bool compact;
  final int? memberCount;
  final VoidCallback? onClose;

  String _memberLabel(int count) {
    final lastTwo = count % 100;
    final one = count % 10 == 1 && lastTwo != 11;
    final few =
        count % 10 >= 2 && count % 10 <= 4 && (lastTwo < 12 || lastTwo > 14);
    return '$count ${one
        ? 'участник'
        : few
        ? 'участника'
        : 'участников'}';
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('navigation-guild-header-surface'),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: GcColors.borderSubtle)),
    ),
    child: ConstrainedBox(
      key: const ValueKey('navigation-guild-header'),
      constraints: const BoxConstraints(minHeight: GcLayout.headerHeight),
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 12 : 16, right: 16),
        child: Row(
          children: [
            WorkspaceGuildMark(guildName: guildName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GuildName(
                    guildName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 20 / 15,
                    ),
                  ),
                  if (memberCount != null)
                    Text(
                      _memberLabel(memberCount!),
                      style: const TextStyle(
                        color: GcColors.muted,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
              key: ValueKey('navigation-guild-chevron'),
              width: 36,
              height: 36,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: GcColors.textSecondary,
              ),
            ),
            if (onClose != null)
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: 'Закрыть навигацию',
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
