import '../native_bindings.dart';

Future<void> workspaceShowScreenShareSetup(
  BuildContext context,
  AppState state,
) async {
  final updating = state.screenSharePhase == ScreenSharePhase.sharing;
  final mobile =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final selection = await ScreenShareSetupDialog.show(
    context,
    initialQuality: state.screenShareSelectedQuality,
    initialContentMode: state.screenShareContentMode,
    allowSourceSelection: !mobile && !updating,
    updating: updating,
  );
  if (!context.mounted || selection == null) return;
  if (updating) {
    state.updateScreenShareContentMode(selection.contentMode);
    await state.updateScreenShareQuality(selection.quality);
    return;
  }
  await state.startScreenShare(
    sourceId: selection.sourceId,
    quality: selection.quality,
    sourceDimensions: selection.sourceDimensions,
    captureScreenAudio: selection.captureScreenAudio,
    contentMode: selection.contentMode,
  );
}
