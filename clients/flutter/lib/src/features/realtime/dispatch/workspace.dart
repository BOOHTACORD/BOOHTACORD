import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../session/own_sessions/hint.dart';
import '../../telemetry/realtime/process.dart';
import 'conversation_events.dart';
import 'direct_message.dart';
import 'screen_preview_event.dart';
import 'member_profile.dart';

class WorkspaceRealtimeDispatch {
  WorkspaceRealtimeDispatch(
    this.workspace,
    this.conversation, {
    required this.notifyMessage,
    required this.voiceRevoked,
    required this.permissionsChanged,
    this.guildChanged,
    this.profileChanged,
    this.screenPreviewUpdated,
    this.screenPreviewInvalidated,
    this.screenViewersChanged,
  });
  final WorkspaceController workspace;
  final ConversationController conversation;
  final void Function(RealtimeEvent) notifyMessage;
  final FutureOr<void> Function(Map<String, dynamic>) voiceRevoked;
  final FutureOr<void> Function() permissionsChanged;
  final FutureOr<void> Function(int)? guildChanged;
  final FutureOr<void> Function()? screenViewersChanged;
  final FutureOr<void> Function(String, int)? profileChanged;
  final void Function(Map<String, dynamic>)? screenPreviewUpdated;
  final void Function(Map<String, dynamic>)? screenPreviewInvalidated;
  Future<void> call(RealtimeEvent event) async {
    if (await dispatchMemberProfileUpdated(event, workspace, profileChanged))
      return;
    if (await dispatchConversationEvent(
      event,
      workspace,
      conversation,
      notifyMessage,
    ))
      return;
    if (dispatchScreenPreviewEvent(
      event,
      screenPreviewUpdated,
      screenPreviewInvalidated,
    ))
      return;
    final payload = event.payload;
    switch (event.kind) {
      case 'guild.profile.updated':
        final revision = payload['revision'];
        if (payload.length == 1 && revision is int && revision > 0) {
          await guildChanged?.call(revision);
        }
      case 'session.state_changed':
        if (payload.isEmpty) notifyOwnSessionsChanged();
      case 'presence.snapshot':
        workspace.guildPresence.acceptSnapshot(payload['online_user_ids']);
      case 'presence.changed':
        workspace.guildPresence.acceptChange(
          payload['user_id'],
          payload['presence'],
        );
      case 'channel.updated':
        await processEffect(
          event,
          conversation.api.transport.session.telemetry,
          () => workspace.refreshTopology(strict: true),
        );
      case 'role.permissions.updated':
      case 'auth.permissions.invalidated':
        await processEffect(
          event,
          conversation.api.transport.session.telemetry,
          () => Future<void>.sync(permissionsChanged),
        );
      case 'screen_viewers.changed':
        if (payload.isEmpty) await screenViewersChanged?.call();
      case 'connection.ready':
        await guildChanged?.call(0);
        await permissionsChanged();
        await screenViewersChanged?.call();
      case 'connection.resync_required':
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
                conversation.refreshSelectedTextHistory(
                  strict: true,
                  replace: true,
                ),
              if (conversation.selectedDirectMessage != null)
                refreshDirectEvent(conversation, null, true),
              if (screenViewersChanged != null)
                Future<void>.sync(screenViewersChanged!),
            ]);
          },
        );
      case 'voice.lease_revoked':
        await processEffect(
          event,
          conversation.api.transport.session.telemetry,
          () => Future<void>.sync(() => voiceRevoked(payload)),
        );
    }
  }
}
