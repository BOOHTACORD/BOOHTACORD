import 'connected_controls/handler.dart';
import 'disconnect_notice/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

import 'package:boohtacord_desktop/src/features/workspace/short_viewport/policy.dart';

mixin WorkspaceVoiceDockBuildBinding on WorkspaceVoiceDockContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceVoiceDockBuild(context);
  }
}

extension WorkspaceVoiceDockBuildAction on WorkspaceVoiceDockContext {
  Widget executeWorkspaceVoiceDockBuild(BuildContext context) {
    final inline =
        compact &&
        workspaceConnected &&
        !state.voiceStreamStartNotice &&
        shortNativeEditingViewport(context);
    return Container(
      key: ValueKey(compact ? 'mobile-voice-dock' : 'voice-dock'),
      padding: inline
          ? const EdgeInsets.symmetric(horizontal: 4)
          : compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: GcColors.surface,
        border: Border(top: BorderSide(color: GcColors.border)),
      ),
      child: inline
          ? Row(
              children: [
                Expanded(child: renderVoiceDockDisconnectNotice()),
                const SizedBox(width: 4),
                SizedBox(
                  width: 240,
                  child: renderVoiceDockConnectedControls(context),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                renderVoiceDockDisconnectNotice(),
                if (state.voiceStreamStartNotice) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'В канале началась демонстрация экрана',
                      style: TextStyle(
                        color: GcColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: compact ? 8 : 11),
                renderVoiceDockConnectedControls(context),
              ],
            ),
    );
  }
}
