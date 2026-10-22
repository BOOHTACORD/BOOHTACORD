import '../native_bindings.dart';

class SupportPublicationNotice extends StatelessWidget {
  const SupportPublicationNotice({
    super.key,
    required this.state,
    required this.conversation,
  });
  final AppState state;
  final DirectConversation conversation;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${state.supportChanged ? 'Оператор поддержки изменился. Старые диалоги сохраняют прежних участников и историю. ' : ''}${state.supportContact.privacyFor(conversation.participantId)}',
            style: const TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
      ),
      if (state.supportPublicationBlocked(conversation) &&
          !state.supportContact.product)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Общая поддержка отключена для этой установки. Новые сообщения не отправляются.',
          ),
        ),
      if (state.supportPublicationBlocked(conversation) &&
          state.supportContact.product)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton(
            onPressed:
                state.supportConsenting || !state.supportContact.available
                ? null
                : state.acceptSupportPublication,
            child: Text(
              state.supportConsenting ? 'Сохраняем…' : 'Согласен на публикацию',
            ),
          ),
        ),
    ],
  );
}
