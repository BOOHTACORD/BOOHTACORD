import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceScreenStateWorkspaceHandleHardwareKeyBinding
    on WorkspaceScreenStateContext {
  @override
  bool workspaceHandleHardwareKey(KeyEvent event) {
    return executeWorkspaceScreenStateWorkspaceHandleHardwareKey(event);
  }
}

extension WorkspaceScreenStateWorkspaceHandleHardwareKeyAction
    on WorkspaceScreenStateContext {
  bool executeWorkspaceScreenStateWorkspaceHandleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent) widget.state.realtime.reportActivity();
    if (!workspaceShortcutAvailability.foreground ||
        ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }
    if (!kIsWeb &&
        event is KeyDownEvent &&
        !workspaceShortcutAvailability.hardwareKeyboard) {
      workspaceMutateView(workspaceShortcutAvailability.observeHardwareKey);
    }
    if (workspaceCapturingVoiceShortcut != null) {
      if (widget.state.workspacePanel != WorkspacePanel.audio ||
          shortcutInputFocused()) {
        workspaceMutateView(() => workspaceCapturingVoiceShortcut = null);
        return false;
      }
      final action = workspaceCapturingVoiceShortcut!;
      final capture = captureVoiceShortcut(event, HardwareKeyboard.instance);
      if (capture.kind == ShortcutCaptureKind.wait) return true;
      workspaceMutateView(() => workspaceCapturingVoiceShortcut = null);
      if (capture.kind == ShortcutCaptureKind.navigate) return false;
      if (capture.kind == ShortcutCaptureKind.clear ||
          capture.kind == ShortcutCaptureKind.assign) {
        unawaited(widget.state.setVoiceShortcut(action, capture.binding));
      }
      return true;
    }
    if (workspaceCapturingPttKey && event is KeyDownEvent) {
      workspaceMutateView(() => workspaceCapturingPttKey = false);
      if (event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        return true;
      }
      final keyLabel = event.logicalKey.keyLabel.trim().isEmpty
          ? event.logicalKey.debugName ?? 'Клавиша'
          : event.logicalKey.keyLabel;
      unawaited(
        widget.state.setPushToTalkKey(event.logicalKey.keyId, keyLabel),
      );
      return true;
    }
    if (event is KeyDownEvent && workspaceHandleVoiceShortcut(event)) {
      return true;
    }
    final isPttKey = widget.state.pushToTalkKeyId == event.logicalKey.keyId;
    if (event is KeyUpEvent && isPttKey) {
      unawaited(widget.state.setPushToTalkPressed(false));
      return true;
    }
    if (event is KeyDownEvent &&
        isPttKey &&
        widget.state.audioActivationMode == AudioActivationMode.ptt) {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext != null &&
          (focusContext.widget is EditableText ||
              focusContext.widget is ButtonStyleButton ||
              focusContext.findAncestorWidgetOfExactType<EditableText>() !=
                  null ||
              focusContext
                      .findAncestorWidgetOfExactType<
                        DropdownButton<String>
                      >() !=
                  null ||
              focusContext
                      .findAncestorWidgetOfExactType<
                        FormField<AudioActivationMode>
                      >() !=
                  null ||
              focusContext.findAncestorWidgetOfExactType<SwitchListTile>() !=
                  null ||
              focusContext.findAncestorWidgetOfExactType<Dialog>() != null)) {
        return false;
      }
      unawaited(widget.state.setPushToTalkPressed(true));
      return true;
    }
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      return workspaceHandleEscape();
    }
    if (event.logicalKey != LogicalKeyboardKey.keyK ||
        (!HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isMetaPressed)) {
      return false;
    }
    return workspaceHandleSearchShortcut();
  }
}
