import 'dart:async';

import '../../profile/revision/cache.dart';
import '../../telemetry/realtime/process.dart';
import '../../workspace/lifecycle/controller.dart';
import '../lifecycle/event.dart';

Future<bool> dispatchMemberProfileUpdated(
  RealtimeEvent event,
  WorkspaceController workspace,
  FutureOr<void> Function(String, int)? profileChanged,
) async {
  if (event.kind != 'member.profile.updated') return false;
  final hint = parseMemberProfileHint(event.payload);
  if (hint == null) return true;
  await processEffect(
    event,
    workspace.api.transport.session.telemetry,
    () async {
      await workspace.refreshMemberProfile(hint.userId, hint.revision);
      await profileChanged?.call(hint.userId, hint.revision);
    },
  );
  return true;
}
