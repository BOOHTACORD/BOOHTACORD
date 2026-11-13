import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';

Future<void> refreshTextEvent(
  ConversationController conversation,
  WorkspaceController workspace,
  String? messageID, [
  bool Function()? socketCurrent,
]) async {
  final active = conversation.admission();
  await conversation.refreshSelectedTextHistory(
    strict: true,
    at: messageID,
    socketCurrent: socketCurrent,
  );
  if (!active() || !(socketCurrent?.call() ?? true)) return;
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
