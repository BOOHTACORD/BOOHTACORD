part of 'noise_suppression_settings.dart';

class _NoiseModeSelector extends StatelessWidget {
  const _NoiseModeSelector({
    required this.processing,
    required this.runtime,
    required this.deepEnabled,
    required this.onChanged,
  });
  final AudioProcessingPreferences processing;
  final NativeNoiseSuppressionState runtime;
  final bool deepEnabled;
  final Future<void> Function(AudioProcessingPreferences) onChanged;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    final modes = NoiseSuppressionMode.values
        .where(
          (mode) =>
              (mode != NoiseSuppressionMode.auto ||
                  (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.windows) ||
                  processing.noiseSuppressionMode == mode) &&
              (mode != NoiseSuppressionMode.deepfilter ||
                  deepEnabled ||
                  processing.noiseSuppressionMode == mode),
        )
        .toList();
    String rnnoiseLabel() {
      final model = runtime.rnnoiseModelId;
      if (model == 'rnnoise-stock-v0.1') return 'RNNoise 0.1';
      if (model == 'rnnoise-stock-v0.2' || model == 'rnnoise-release-v0.2')
        return 'RNNoise 0.2';
      if (model != null) return 'RNNoise — версия неизвестна';
      return !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? 'RNNoise 0.2'
          : 'RNNoise 0.1';
    }

    String selectedLabel(NoiseSuppressionMode mode) => switch (mode) {
      NoiseSuppressionMode.off => 'Выключено',
      NoiseSuppressionMode.browser =>
        compact ? 'WebRTC' : _NoiseStatusText.label(mode.name),
      NoiseSuppressionMode.rnnoise => rnnoiseLabel(),
      NoiseSuppressionMode.deepfilter =>
        deepEnabled ? 'DeepFilterNet3' : 'DeepFilterNet3 — недоступен',
      NoiseSuppressionMode.auto => 'Автоматически',
    };
    return DropdownButtonFormField<NoiseSuppressionMode>(
      key: ValueKey(processing.noiseSuppressionMode),
      initialValue: processing.noiseSuppressionMode,
      isExpanded: true,
      selectedItemBuilder: (context) => [
        for (final mode in modes)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              selectedLabel(mode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      decoration: const InputDecoration(labelText: 'Шумоподавление'),
      items: [
        for (final mode in modes)
          DropdownMenuItem(
            value: mode,
            enabled:
                (mode != NoiseSuppressionMode.rnnoise ||
                    runtime.status != 'unsupported') &&
                (mode != NoiseSuppressionMode.deepfilter || deepEnabled),
            child: Text(selectedLabel(mode)),
          ),
      ],
      onChanged: (mode) {
        if (mode != null) {
          onChanged(processing.copyWith(noiseSuppressionMode: mode));
        }
      },
    );
  }
}
