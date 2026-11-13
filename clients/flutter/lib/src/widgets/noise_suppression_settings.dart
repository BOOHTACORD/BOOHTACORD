import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/audio_preferences.dart';
import '../services/native_noise_suppression.dart';
import '../theme.dart';

part 'noise_suppression_status_text.dart';
part 'noise_suppression_status_style.dart';
part 'noise_suppression_selector.dart';
part 'noise_suppression_details.dart';

class NoiseSuppressionSettings extends StatelessWidget {
  const NoiseSuppressionSettings({
    super.key,
    required this.processing,
    required this.runtime,
    required this.onChanged,
    this.allowExperimentalDeepFilter,
  });
  final AudioProcessingPreferences processing;
  final NativeNoiseSuppressionState runtime;
  final Future<void> Function(AudioProcessingPreferences) onChanged;
  final bool? allowExperimentalDeepFilter;
  static String label(String mode) => _NoiseStatusText.label(mode);
  static String reason(String? value) => _NoiseStatusText.reason(value);

  @override
  Widget build(BuildContext context) {
    final requestedMode = processing.noiseSuppressionMode;
    final title = _NoiseStatusText._runtimeTitle(runtime, requestedMode);
    final matches = _NoiseStatusText._requestMatches(runtime, requestedMode);
    final color = _NoiseStatusStyle._runtimeColor(
      Theme.of(context).colorScheme,
      runtime,
      requestedMode,
    );
    final deepEnabled =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        (kDebugMode && allowExperimentalDeepFilter != null
            ? allowExperimentalDeepFilter!
            : const bool.fromEnvironment('BOOHTA_EXPERIMENTAL_DEEPFILTER'));
    final showStatus =
        ((requestedMode == NoiseSuppressionMode.rnnoise ||
                requestedMode == NoiseSuppressionMode.deepfilter) &&
            runtime.status != 'idle') ||
        (matches && runtime.status == 'error');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NoiseModeSelector(
          processing: processing,
          runtime: runtime,
          deepEnabled: deepEnabled,
          onChanged: onChanged,
        ),
        if (requestedMode == NoiseSuppressionMode.deepfilter && deepEnabled)
          const Text('Может повысить нагрузку процессора и задержку.'),
        if (showStatus) ...[
          const SizedBox(height: 8),
          Semantics(
            key: const ValueKey('noise-suppression-runtime-status'),
            container: true,
            liveRegion: true,
            label: title,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(
                    _NoiseStatusStyle._runtimeIcon(runtime, requestedMode),
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        _NoiseDetails(runtime: runtime, requestedMode: requestedMode),
      ],
    );
  }
}
