import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../../../../services/screen_share_quality.dart';
import '../../profile/content_mode.dart';
import '../selection/result.dart';
import 'body.dart';
export '../selection/result.dart';

class ScreenShareSetupDialog extends StatelessWidget {
  const ScreenShareSetupDialog({
    super.key,
    required this.initialQuality,
    required this.allowSourceSelection,
    this.updating = false,
    this.capturer,
    this.initialContentMode = ScreenShareContentMode.motion,
  });
  final ScreenShareQuality initialQuality;
  final ScreenShareContentMode initialContentMode;
  final bool allowSourceSelection;
  final bool updating;
  final rtc.DesktopCapturer? capturer;
  static Future<ScreenShareSetupSelection?> show(
    BuildContext context, {
    required ScreenShareQuality initialQuality,
    required bool allowSourceSelection,
    bool updating = false,
    rtc.DesktopCapturer? capturer,
    ScreenShareContentMode initialContentMode = ScreenShareContentMode.motion,
  }) => showDialog<ScreenShareSetupSelection>(
    context: context,
    barrierDismissible: false,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (_) => ScreenShareSetupDialog(
      initialQuality: initialQuality,
      allowSourceSelection: allowSourceSelection,
      updating: updating,
      capturer: capturer,
      initialContentMode: initialContentMode,
    ),
  );
  @override
  Widget build(BuildContext context) => SetupBody(
    initialQuality: initialQuality,
    allowSourceSelection: allowSourceSelection,
    updating: updating,
    capturer: capturer,
    initialContentMode: initialContentMode,
  );
}
