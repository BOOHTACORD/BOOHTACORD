import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../telemetry/realtime/process.dart';
import 'direct_message.dart';
import 'text_message.dart';

Future<bool> dispatchConversationEvent(
  RealtimeEvent event,
  WorkspaceController workspace,
  ConversationController conversation,
  void Function(RealtimeEvent) notifyMessage,
) async {
  final payload = event.payload;
  switch (event.kind) {
    case 'message.created':
    case 'message.updated':
    case 'message.deleted':
      if (workspace.selectedChannel?.id == payload['channel_id']) {
        await refreshReceived(
          event,
          conversation.api.transport.session.telemetry,
          () => refreshTextEvent(
            conversation,
            workspace,
            payload['message_id'] as String?,
          ),
          () => conversation.messages
              .map((message) => (id: message.id, value: message as Object))
              .toList(),
        );
      }
      await workspace.refreshTopology(strict: true);
      if (event.kind == 'message.created') notifyMessage(event);
      return true;
    case 'direct_message.message_created':
    case 'direct_message.message_updated':
    case 'direct_message.message_deleted':
      if (conversation.selectedDirectMessage?.id ==
          payload['direct_message_id']) {
        await refreshReceived(
          event,
          conversation.api.transport.session.telemetry,
          () => refreshDirectEvent(
            conversation,
            payload['message_id'] as String?,
          ),
          () => conversation.directMessageHistory
              .map((message) => (id: message.id, value: message as Object))
              .toList(),
        );
      }
      await workspace.refreshDirectMessages(strict: true);
      if (event.kind == 'direct_message.message_created') notifyMessage(event);
      return true;
    default:
      return false;
  }
}
