import 'package:flutter/material.dart';

import '../devices/state.dart';
import 'scan_notice_copy.dart';

class AudioDeviceScanNotice extends StatelessWidget {
  const AudioDeviceScanNotice({
    required this.status,
    required this.failure,
    required this.inputCount,
    required this.outputCount,
    super.key,
  });

  final AudioDeviceScanStatus status;
  final AudioDeviceScanFailure? failure;
  final int inputCount;
  final int outputCount;

  @override
  Widget build(BuildContext context) {
    final notice = AudioDeviceScanNoticeCopy.fromState(
      status: status,
      failure: failure,
      inputCount: inputCount,
      outputCount: outputCount,
    );
    if (notice == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final color = switch (notice.tone) {
      AudioDeviceNoticeTone.pending => colors.primary,
      AudioDeviceNoticeTone.warning => colors.error,
    };
    return Semantics(
      key: const ValueKey('audio-device-scan-notice'),
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(notice.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title, style: TextStyle(color: color)),
                  if (notice.detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      notice.detail!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
