import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/transport.dart';

class DirectMessagesApi {
  DirectMessagesApi(this.transport);
  final ApiTransport transport;

  Future<DirectChatMessage> sendDirectMessage(
    String id,
    String clientMessageId,
    String body, {
    String? replyToId,
    List<String> mentionUserIds = const [],
    List<String> attachmentIds = const [],
  }) async {
    final data = await transport.checked(
      await transport.client.post(
        transport.uri('/direct-messages/$id/messages'),
        headers: {
          ...await transport.headers(jsonBody: true),
          'X-Boohtacord-Support-Publication': 'v1',
        },
        body: jsonEncode({
          'client_message_id': clientMessageId,
          'body': body,
          'reply_to_id': ?replyToId,
          if (mentionUserIds.isNotEmpty) 'mention_user_ids': mentionUserIds,
          if (attachmentIds.isNotEmpty) 'attachment_ids': attachmentIds,
        }),
      ),
    ) as Map<String, dynamic>;
    return DirectChatMessage.fromJson(data);
  }

  Future<DirectChatMessage> editDirectMessage(
    String directMessageId,
    String messageId,
    String body,
    int expectedRevision, {
    List<String> mentionUserIds = const [],
  }) async {
    final data = await transport.checked(
      await transport.client.patch(
        transport.uri('/direct-messages/$directMessageId/messages/$messageId'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'body': body,
          'expected_revision': expectedRevision,
          'mention_user_ids': mentionUserIds,
        }),
      ),
    ) as Map<String, dynamic>;
    return DirectChatMessage.fromJson(data);
  }

  Future<void> deleteDirectMessage(
    String directMessageId,
    String messageId,
  ) async {
    await transport.checked(
      await transport.client.delete(
        transport.uri('/direct-messages/$directMessageId/messages/$messageId'),
        headers: await transport.headers(),
      ),
    );
  }
}
