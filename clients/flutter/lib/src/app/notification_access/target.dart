import '../../models.dart';
import '../../services/api_client.dart';

Future<SearchMessage?> resolveNotificationMessage(
  ApiClient api,
  Map<String, dynamic> target,
) async {
  final conversation = target['conversation_id'], id = target['message_id'];
  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  if (target['version'] != 1 ||
      conversation is! String ||
      id is! String ||
      !uuid.hasMatch(conversation) ||
      !uuid.hasMatch(id)) {
    return null;
  }
  if (target['kind'] == 'DM') {
    final page = await api.directMessageHistoryPage(conversation, at: id);
    final message = page.messages
        .where((m) => m.id == id && !m.deleted)
        .firstOrNull;
    if (message == null) return null;
    return SearchMessage(
      id: id,
      kind: SearchMessageKind.directMessage,
      conversationId: conversation,
      authorId: message.authorId,
      body: message.body,
      createdAt: message.createdAt,
      revision: message.revision,
    );
  }
  if (target['kind'] == 'TEXT') {
    final page = await api.messagePage(conversation, at: id);
    final message = page.messages
        .where((m) => m.id == id && !m.deleted)
        .firstOrNull;
    if (message == null) return null;
    return SearchMessage(
      id: id,
      kind: SearchMessageKind.channel,
      conversationId: conversation,
      authorId: message.authorId,
      body: message.body,
      createdAt: message.createdAt,
      revision: message.revision,
      messageKind: message.kind,
    );
  }
  return null;
}
