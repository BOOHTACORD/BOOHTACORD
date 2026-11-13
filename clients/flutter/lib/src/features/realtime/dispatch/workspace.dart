import 'dart:async';

import '../../conversation/lifecycle/controller.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';
import '../../session/own_sessions/hint.dart';
import '../../telemetry/realtime/process.dart';
import 'conversation_events.dart';
import 'screen_preview_event.dart';
import 'member_profile.dart';
import 'presence.dart';
import 'recovery.dart';

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
    this.notificationHint,
    this.rosterEvent,
    this.maintenanceEvent,
    this.captureCurrent,
  });
  final WorkspaceController workspace;
  final ConversationController conversation;
  final void Function(RealtimeEvent) notifyMessage;
  final FutureOr<void> Function(String?, Map<String, dynamic>)?
  notificationHint;
  final bool Function(RealtimeEvent)? rosterEvent;
  final bool Function(RealtimeEvent)? maintenanceEvent;
  final bool Function() Function()? captureCurrent;
  final FutureOr<void> Function(Map<String, dynamic>) voiceRevoked;
  final FutureOr<void> Function() permissionsChanged;
  final FutureOr<void> Function(int)? guildChanged;
  final FutureOr<void> Function()? screenViewersChanged;
  final FutureOr<void> Function(String, int)? profileChanged;
  final void Function(Map<String, dynamic>)? screenPreviewUpdated;
  final void Function(Map<String, dynamic>)? screenPreviewInvalidated;
  Future<void> call(RealtimeEvent event) async {
    final current = captureCurrent?.call() ?? (() => true);
    if (maintenanceEvent?.call(event) == true) return;
    if (rosterEvent?.call(event) == true) return;
    if (event.kind == 'notification.queued' ||
        event.kind == 'notification.preferences_changed') {
      await notificationHint?.call(event.kind, event.payload);
      return;
    }
    if (await dispatchMemberProfileUpdated(event, workspace, profileChanged)) {
      return;
    }
    if (await dispatchPresence(event, workspace)) return;
    if (await dispatchConversationEvent(
      event,
      workspace,
      conversation,
      notifyMessage,
    )) {
      return;
    }
    if (dispatchScreenPreviewEvent(
      event,
      screenPreviewUpdated,
      screenPreviewInvalidated,
    )) {
      return;
    }
    final payload = event.payload;
    switch (event.kind) {
      case 'guild.profile.updated':
        final revision = payload['revision'];
        if (payload.length == 1 && revision is int && revision > 0) {
          await guildChanged?.call(revision);
        }
      case 'session.state_changed':
        if (payload.isEmpty) notifyOwnSessionsChanged();
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
        await dispatchReady(guildChanged, permissionsChanged, screenViewersChanged, current);
      case 'connection.resync_required':
        await dispatchRecovery(
          event,
          workspace,
          conversation,
          permissionsChanged,
          guildChanged,
          screenViewersChanged,
          current,
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
