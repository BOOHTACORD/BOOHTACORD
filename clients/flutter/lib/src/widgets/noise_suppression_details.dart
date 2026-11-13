part of 'noise_suppression_settings.dart';

class _NoiseDetails extends StatelessWidget {
  const _NoiseDetails({required this.runtime, required this.requestedMode});
  final NativeNoiseSuppressionState runtime;
  final NoiseSuppressionMode requestedMode;

  @override
  Widget build(BuildContext context) {
    final matches = _NoiseStatusText._requestMatches(runtime, requestedMode);
    final title = _NoiseStatusText._runtimeTitle(runtime, requestedMode);
    final detail = _NoiseStatusText._runtimeDetail(runtime, requestedMode);
    final reason = matches
        ? _NoiseStatusText.reason(runtime.failureReason)
        : '';
    return ExpansionTile(
      title: const Text('Сведения об обработке'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      children: [
        Text(detail),
        if (reason.isNotEmpty) Text(reason),
        Text(
          matches
              ? 'Состояние: $title; обработано кадров: ${runtime.processedFrames}; резервных кадров: ${runtime.fallbackFrames}.'
              : 'Состояние: $title.',
        ),
        if (matches)
          Text(
            'Нативный отчёт о режиме: ${_NoiseStatusText.label(runtime.effectiveMode)}.',
          ),
        if (matches &&
            runtime.sampleRate != null &&
            runtime.sampleRate! > 0 &&
            runtime.channels != null &&
            runtime.channels! > 0)
          Text('PCM: ${runtime.sampleRate} Гц; каналы: ${runtime.channels}.'),
        if (requestedMode == NoiseSuppressionMode.rnnoise &&
            _NoiseStatusText._rnnoiseConfirmed(runtime, requestedMode))
          const Text(
            'Модель RNNoise: rnnoise-stock-v0.1. Время инициализации нативного DSP: недоступно.',
          ),
        const Text('Эти данные не оценивают качество звука.'),
      ],
    );
  }
}
