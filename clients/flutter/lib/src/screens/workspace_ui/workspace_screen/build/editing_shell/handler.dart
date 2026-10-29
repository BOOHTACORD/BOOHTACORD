import 'package:boohtacord_desktop/src/features/workspace/short_viewport/policy.dart';

import '../../../../../features/realtime/lifecycle/status.dart';
import '../../../../../features/notifications/settings/notice.dart';
import '../../../voice_dock/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension WorkspaceEditingShell on WorkspaceScreenStateContext {
  Column renderWorkspaceEditingShell(Widget content, bool compact) {
    final voice = compact && widget.state.voiceChannel != null;
    final inline =
        voice &&
        shortNativeEditingViewport(context) &&
        (widget.state.voicePhase == VoicePhase.connected ||
            widget.state.voicePhase == VoicePhase.listener) &&
        !widget.state.voiceStreamStartNotice;
    final primary = voice && !inline
        ? Column(
            children: [
              Expanded(child: content),
              WorkspaceVoiceDock(state: widget.state, compact: true),
            ],
          )
        : content;
    return Column(
      children: [
        if (inline)
          Row(
            children: [
              Expanded(
                child: RealtimeRecoveryStatus(
                  controller: widget.state.realtime,
                ),
              ),
              Expanded(
                child: WorkspaceVoiceDock(state: widget.state, compact: true),
              ),
            ],
          )
        else
          RealtimeRecoveryStatus(controller: widget.state.realtime),
        RemoteNotificationNotice(controller: widget.state.remoteNotifications),
        Expanded(child: primary),
      ],
    );
  }
}
