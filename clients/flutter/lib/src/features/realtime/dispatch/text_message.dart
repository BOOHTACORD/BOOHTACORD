import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';

Future<void> refreshTextEvent(
  ConversationController conversation,
  WorkspaceController workspace,
  String? messageID,
) async {
  final active = conversation.admission();
  await conversation.refreshSelectedTextHistory(strict: true, at: messageID);
  if (!active()) return;
  final welcome = conversation.messages
      .where(
        (message) =>
            message.id == messageID && message.kind == 'SYSTEM_WELCOME',
      )
      .firstOrNull;
  if (welcome != null &&
      !workspace.members.any((member) => member.id == welcome.authorId)) {
    await workspace.refreshMembers();
  }
}
