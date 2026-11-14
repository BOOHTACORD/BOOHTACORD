import '../../native_bindings.dart';
import '../../../../features/realtime/lifecycle/voice_activity_heartbeat.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateInitStateBinding on WorkspaceScreenStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceScreenStateInitState();
  }
}

extension WorkspaceScreenStateInitStateAction on WorkspaceScreenStateContext {
  void executeWorkspaceScreenStateInitState() {
    workspaceShortcutAccount = widget.state.user?.accountId;
    workspaceVoiceActivityHeartbeat = VoiceActivityHeartbeat(
      isSpeaking: () {
        final voice = widget.state.voice;
        return voice.voicePhase == VoicePhase.connected &&
            voice.microphoneAllowed &&
            !voice.microphoneMuted &&
            !voice.deafened &&
            voice.room?.localParticipant?.isSpeaking == true;
      },
      reportActivity: widget.state.realtime.reportActivity,
    )..start();
    workspaceLastObservedScreenSharePhase = widget.state.screenSharePhase;
    workspaceLastWorkspacePanel = widget.state.workspacePanel;
    widget.state.addListener(workspaceWorkspaceChanged);
    HardwareKeyboard.instance.addHandler(workspaceHandleHardwareKey);
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      windowManager.addListener(this);
    }
  }
}
