import '../../../native_bindings.dart';

class VoiceRoomHeaderActions extends StatelessWidget {
  const VoiceRoomHeaderActions({
    super.key,
    this.onSearch,
    this.onOpenMembers,
    this.compact = false,
    this.sharing = false,
    this.shareBusy = false,
    this.onConfigureShare,
    this.onToggleShare,
  });

  final VoidCallback? onSearch;
  final VoidCallback? onOpenMembers;
  final bool compact;
  final bool sharing;
  final bool shareBusy;
  final VoidCallback? onConfigureShare;
  final VoidCallback? onToggleShare;

  @override
  Widget build(BuildContext context) {
    final actionSize = compact ? 44.0 : 48.0;
    final actionConstraints = BoxConstraints.tightFor(
      width: actionSize,
      height: actionSize,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact && onConfigureShare != null)
          IconButton(
            tooltip: 'Изменить качество и FPS',
            constraints: actionConstraints,
            padding: EdgeInsets.zero,
            onPressed: onConfigureShare,
            icon: const Icon(Icons.tune),
          ),
        if (!compact && (onToggleShare != null || shareBusy))
          IconButton(
            tooltip: shareBusy
                ? 'Демонстрация экрана обновляется'
                : sharing
                ? 'Остановить демонстрацию экрана'
                : 'Начать демонстрацию экрана',
            constraints: actionConstraints,
            padding: EdgeInsets.zero,
            onPressed: shareBusy ? null : onToggleShare,
            icon: shareBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    sharing
                        ? Icons.stop_screen_share_outlined
                        : Icons.screen_share_outlined,
                  ),
          ),
        if (onSearch != null)
          IconButton(
            tooltip: 'Найти сообщение',
            constraints: actionConstraints,
            padding: EdgeInsets.zero,
            onPressed: onSearch,
            icon: const Icon(Icons.search),
          ),
        if (onOpenMembers != null)
          IconButton(
            tooltip: 'Открыть участников',
            constraints: actionConstraints,
            padding: EdgeInsets.zero,
            onPressed: onOpenMembers,
            icon: const Icon(Icons.people_outline),
          ),
        if (onSearch != null || onOpenMembers != null)
          PopupMenuButton<String>(
            tooltip: 'Другие действия',
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
            icon: const Icon(Icons.more_horiz),
            onSelected: (action) {
              if (action == 'search') onSearch?.call();
              if (action == 'members') onOpenMembers?.call();
              if (action == 'configure-share') onConfigureShare?.call();
              if (action == 'toggle-share' && !shareBusy) onToggleShare?.call();
            },
            itemBuilder: (_) => [
              if (onSearch != null)
                const PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18),
                      SizedBox(width: 12),
                      Text('Найти сообщение'),
                    ],
                  ),
                ),
              if (onOpenMembers != null)
                const PopupMenuItem(
                  value: 'members',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline, size: 18),
                      SizedBox(width: 12),
                      Text('К участникам'),
                    ],
                  ),
                ),
              if (compact && onConfigureShare != null)
                const PopupMenuItem(
                  value: 'configure-share',
                  child: Row(
                    children: [
                      Icon(Icons.tune, size: 18),
                      SizedBox(width: 12),
                      Text('Качество трансляции'),
                    ],
                  ),
                ),
              if (compact && (onToggleShare != null || shareBusy))
                PopupMenuItem(
                  value: 'toggle-share',
                  enabled: !shareBusy && onToggleShare != null,
                  child: Row(
                    children: [
                      Icon(
                        sharing
                            ? Icons.stop_screen_share_outlined
                            : Icons.screen_share_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        shareBusy
                            ? 'Демонстрация экрана…'
                            : sharing
                            ? 'Остановить демонстрацию'
                            : 'Начать демонстрацию',
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
