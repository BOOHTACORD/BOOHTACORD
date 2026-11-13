import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../../telemetry/realtime/process.dart';
import '../lifecycle/event.dart';
import 'direct_message.dart';

Future<void> dispatchReady(
  FutureOr<void> Function(int)? guildChanged,
  FutureOr<void> Function() permissionsChanged,
  FutureOr<void> Function()? screenViewersChanged,
  bool Function() current,
) async {
  if (!current()) return;
  await guildChanged?.call(0);
  if (!current()) return;
  await permissionsChanged();
  if (current()) await screenViewersChanged?.call();
}

Future<void> dispatchRecovery(
  RealtimeEvent event,
  WorkspaceController workspace,
  ConversationController conversation,
  FutureOr<void> Function() permissionsChanged,
  FutureOr<void> Function(int)? guildChanged,
  FutureOr<void> Function()? screenViewersChanged,
  bool Function() current,
) async {
  if (!current()) return;
  await guildChanged?.call(0);
  if (!current()) return;
  await processEffect(
    event,
    conversation.api.transport.session.telemetry,
    () async {
      await workspace.refreshTopology(strict: true);
      if (!current()) return;
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
