import 'package:flutter/material.dart';

import '../../features/workspace/quick_jump/state/entry.dart';
import '../../models.dart';

class QuickJumpRow extends StatelessWidget {
  const QuickJumpRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onOpen,
  });
  final QuickJumpEntry entry;
  final bool selected, enabled;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ListTile(
    key: ValueKey(
      'quick-jump-${entry.isPerson ? 'person' : 'channel'}-${entry.targetId}',
    ),
    selected: selected,
    enabled: enabled,
    onTap: enabled ? onOpen : null,
    leading: Icon(
      entry.isPerson
          ? Icons.person_outline
          : entry.channel?.kind == ChannelKind.voice
          ? Icons.volume_up_outlined
          : Icons.tag,
    ),
    title: Text(entry.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      entry.isPerson
          ? entry.direct == null
                ? 'Участник гильдии'
                : 'Личное сообщение'
          : entry.channel?.kind == ChannelKind.voice
          ? 'Открыть комнату без подключения'
          : 'Текстовый канал',
    ),
    minTileHeight: 56,
  );
}
