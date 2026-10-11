import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../capabilities/preflight.dart';
import '../../capabilities/notice.dart';
import 'mobile_notice.dart';

/// Keep capture availability ahead of choices, with additional Android guidance
/// after choices. All content scrolls together while the action footer stays put.
class SetupQualityContent extends StatelessWidget {
  const SetupQualityContent({
    super.key,
    required this.capability,
    required this.updating,
    required this.picker,
    required this.captureScreenAudio,
    required this.onCaptureScreenAudioChanged,
  });
  final ScreenPreflight capability;
  final bool updating;
  final Widget picker;
  final bool captureScreenAudio;
  final ValueChanged<bool> onCaptureScreenAudioChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      children: [
        ScreenCapabilityNotice(capability: capability),
        if (capability.captureAudioConfigured && !updating)
          SwitchListTile.adaptive(
            key: const ValueKey('capture-screen-audio'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            value: captureScreenAudio,
            onChanged: onCaptureScreenAudioChanged,
            title: const Text('Передавать звук экрана'),
            subtitle: const Text(
              'Звук игры или приложения передаётся, если источник и система разрешают захват.',
            ),
          ),
        picker,
        if (!updating &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)) ...[
          MobileCaptureNotice(captureScreenAudio: captureScreenAudio),
          const SizedBox(height: 8),
        ],
      ],
    ),
  );
}
