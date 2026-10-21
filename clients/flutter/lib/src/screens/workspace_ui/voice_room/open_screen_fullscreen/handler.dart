import '../../../screen_fullscreen_route.dart';
import 'fullscreen_content/handler.dart';
import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreenBinding
    on WorkspaceVoiceRoomStateContext {
  @override
  Future<void> workspaceOpenScreenFullscreen({
    required VideoTrack track,
    required String publisherName,
    required String? publisherIdentity,
    required Object viewerGeneration,
    required VoidCallback? onFirstFrameRendered,
    required bool showingLocalScreen,
  }) {
    return executeWorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreen(
      track: track,
      publisherName: publisherName,
      publisherIdentity: publisherIdentity,
      viewerGeneration: viewerGeneration,
      onFirstFrameRendered: onFirstFrameRendered,
      showingLocalScreen: showingLocalScreen,
    );
  }
}

extension WorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreenAction
    on WorkspaceVoiceRoomStateContext {
  Future<void> executeWorkspaceVoiceRoomStateWorkspaceOpenScreenFullscreen({
    required VideoTrack track,
    required String publisherName,
    required String? publisherIdentity,
    required Object viewerGeneration,
    required VoidCallback? onFirstFrameRendered,
    required bool showingLocalScreen,
  }) async {
    await presentScreenFullscreen(
      context: context,
      state: widget.state,
      publisherIdentity: publisherIdentity,
      generation: viewerGeneration,
      onSelectionChanged: widget.onFullscreenSelectionChanged,
      content: (lease, target) => renderVoiceRoomFullscreenContent(
        publisherName,
        viewerGeneration,
        onFirstFrameRendered,
        showingLocalScreen,
        lease,
        track,
        target,
      ),
    );
  }
}
