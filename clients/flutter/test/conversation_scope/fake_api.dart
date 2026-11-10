import 'dart:async';
import 'dart:typed_data';

import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

const conversationA = DirectConversation(
  id: 'a',
  participantId: 'peer-a',
  displayName: 'A',
  unreadCount: 0,
);
const conversationB = DirectConversation(
  id: 'b',
  participantId: 'peer-b',
  displayName: 'B',
  unreadCount: 0,
);

DirectChatMessage message(String id) => DirectChatMessage(
  id: id,
  directMessageId: 'a',
  authorId: 'peer-a',
  body: id,
  createdAt: DateTime(2026),
  deleted: false,
  revision: 1,
);

class ConversationFakeApi extends ApiClient {
  @override
  bool get realtimeEnabled => false;

  final firstPage = Completer<DirectChatMessagePage>();
  final uploaded = Completer<MessageAttachment>();
  int requests = 0;
  @override
  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
    int limit = 50,
  }) async {
    requests++;
    if (requests == 1) return firstPage.future;
    return DirectChatMessagePage(messages: id == 'a' ? [message('new')] : []);
  }

  @override
  Future<MessageAttachment> uploadChannelAttachment(
    String channelId,
    String fileName,
    Uint8List bytes, {
    void Function(int, int)? onProgress,
  }) => uploaded.future;
  @override
  Future<void> logout() async {}
}
