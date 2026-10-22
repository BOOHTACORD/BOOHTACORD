import '../native_bindings.dart';

class SupportContactRow extends StatelessWidget {
  const SupportContactRow({super.key, required this.state, this.onSelected});
  final AppState state;
  final VoidCallback? onSelected;
  @override
  Widget build(BuildContext context) {
    final existing = state.directMessages
        .where(state.isSupportConversation)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.supportAvailable)
          Material(
            color: Colors.transparent,
            child: ListTile(
              minTileHeight: 48,
              leading: const Icon(Icons.help_outline, color: GcColors.muted),
              title: const Text('Поддержка'),
              subtitle: const Text('Поддержка этого сервера · закреплено'),
              selected:
                  existing != null &&
                  state.selectedDirectMessage?.id == existing.id,
              selectedTileColor: GcColors.selected,
              trailing: existing != null && existing.unreadCount > 0
                  ? Badge(label: Text('${existing.unreadCount}'))
                  : null,
              enabled: !state.supportOpening,
              onTap: () async {
                if (await state.openSupport() && context.mounted) {
                  onSelected?.call();
                }
              },
            ),
          ),
        if (state.supportNotice != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                state.supportNotice!,
                style: const TextStyle(color: GcColors.muted),
              ),
            ),
          ),
        if (state.supportChanged)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Оператор поддержки изменился. Старые диалоги сохраняют прежних участников и историю.',
              style: TextStyle(color: GcColors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
