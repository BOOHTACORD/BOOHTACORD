import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateDisposeBinding on WorkspaceScreenStateContext {
  @override
  void dispose() {
    executeWorkspaceScreenStateDispose();
    super.dispose();
  }
}

extension WorkspaceScreenStateDisposeAction on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateDispose() {
    workspaceVoiceActivityHeartbeat.stop();
    widget.state.voice.cancelVoiceShortcuts();
    HardwareKeyboard.instance.removeHandler(workspaceHandleHardwareKey);
    WidgetsBinding.instance.removeObserver(this);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.removeListener(this);
    }
    unawaited(widget.state.setPushToTalkPressed(false));
    widget.state.removeListener(workspaceWorkspaceChanged);
    workspaceSearchTriggerFocus.dispose();
  }
}
