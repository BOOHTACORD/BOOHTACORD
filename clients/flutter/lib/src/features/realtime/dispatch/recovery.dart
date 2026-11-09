import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../../telemetry/realtime/process.dart';
import '../lifecycle/event.dart';
import 'direct_message.dart';

Future<void> dispatchRecovery(
  RealtimeEvent event,
  WorkspaceController workspace,
  ConversationController conversation,
  FutureOr<void> Function() permissionsChanged,
  FutureOr<void> Function(int)? guildChanged,
  FutureOr<void> Function()? screenViewersChanged,
) async {
  await guildChanged?.call(0);
  await processEffect(
    event,
    conversation.api.transport.session.telemetry,
    () async {
      await workspace.refreshTopology(strict: true);
      await Future.wait<void>([
        workspace.refreshMembers(strict: true),
        workspace.refreshDirectMessages(strict: true),
        Future<void>.sync(permissionsChanged),
        if (workspace.selectedChannel?.kind == ChannelKind.text)
          conversation.refreshSelectedTextHistory(strict: true, replace: true),
        if (conversation.selectedDirectMessage != null)
          refreshDirectEvent(conversation, null, true),
        if (screenViewersChanged != null)
          Future<void>.sync(screenViewersChanged),
      ]);
    },
  );
}
