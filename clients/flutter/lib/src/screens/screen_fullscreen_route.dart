import 'package:flutter/material.dart';

import '../app_state.dart';
import '../features/voice/screen_viewer/fullscreen_generation.dart';
import '../features/screen/lifecycle/types.dart';
import '../widgets/screen_video_renderer_slot.dart';
import 'screen_fullscreen_overlay.dart';

final _presenting = Expando<bool>();

/// The same renderer hand-off and native presentation for stage and pinned view.
Future<void> presentScreenFullscreen({
  required BuildContext context,
  required AppState state,
  required String? publisherIdentity,
  required Object generation,
  required ValueChanged<ScreenFullscreenSelection?> onSelectionChanged,
  required Widget Function(ScreenFullscreenRendererLease, BuildContext) content,
}) async {
  if (_presenting[state] == true) return;
  _presenting[state] = true;
  ScreenFullscreenPresentation? presentation;
  final lease = ScreenFullscreenRendererLease();
  final capturedRoom = state.room;
  BuildContext? dialog;
  var closing = false;
  bool published() => screenFullscreenGenerationIsPublished(
    room: state.room,
    capturedRoom: capturedRoom,
    publisherIdentity: publisherIdentity,
    viewerGeneration: generation,
    localCaptureActive: state.screenSharePhase == ScreenSharePhase.sharing,
  );
  void closeWhenEnded() {
    final target = dialog;
    if (closing || target == null || !target.mounted || published()) return;
    closing = true;
    lease.expire(() {
      final route = ModalRoute.of(target);
      if (route?.isCurrent == true) {
        Navigator.of(target).pop();
      } else if (route?.isActive == true) {
        route!.navigator?.removeRoute(route);
      }
    });
  }

  onSelectionChanged(
    ScreenFullscreenSelection(
      identity: publisherIdentity,
      generation: generation,
    ),
  );
  try {
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted || !published()) return;
    presentation = await ScreenFullscreenPresentation.enter();
    if (!context.mounted || !published()) return;
    state.addListener(closeWhenEnded);
    capturedRoom?.addListener(closeWhenEnded);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть полноэкранный режим',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (target, _, _) {
        dialog = target;
        WidgetsBinding.instance.addPostFrameCallback((_) => closeWhenEnded());
        return content(lease, target);
      },
    );
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось развернуть демонстрацию на весь экран.'),
        ),
      );
  } finally {
    state.removeListener(closeWhenEnded);
    capturedRoom?.removeListener(closeWhenEnded);
    // Do not remount the mini/stage while the outgoing route still renders.
    lease.expire(() {});
    await WidgetsBinding.instance.endOfFrame;
    lease.dispose();
    await presentation?.restore();
    onSelectionChanged(null);
    _presenting[state] = false;
  }
}
