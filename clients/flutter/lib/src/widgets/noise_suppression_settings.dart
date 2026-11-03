import 'package:flutter/material.dart';

import '../services/audio_preferences.dart';
import '../services/native_noise_suppression.dart';
import '../theme.dart';

class NoiseSuppressionSettings extends StatelessWidget {
  const NoiseSuppressionSettings({
    super.key,
    required this.processing,
    required this.runtime,
    required this.onChanged,
  });
  final AudioProcessingPreferences processing;
  final NativeNoiseSuppressionState runtime;
  final Future<void> Function(AudioProcessingPreferences) onChanged;
  static String label(String mode) => switch (mode) {
    'off' => 'Выключено',
    'browser' => 'Стандартное — WebRTC',
    'rnnoise' => 'RNNoise',
    _ => 'Неизвестно',
  };
  static String reason(String? reason) => switch (reason) {
    'platform-aec-ns-coupled' =>
      'На этой платформе нативное шумоподавление связано с эхоподавлением.',
    'hardware-noise-suppression-active' => 'Аппаратный шумодав уже активен.',
    'unsupported-audio-format' =>
      'Формат микрофона не поддерживается фильтром.',
    'invalid-audio-samples' => 'Аудиопроцессор получил некорректные данные.',
    'browser-recovery-failed' || 'rollback-failed' =>
      'Не удалось восстановить микрофон. Отправка звука выключена.',
    'input-switch-failed' =>
      'Не удалось переключить микрофон. Он отключён до восстановления.',
    'unsupported' => 'Нативный фильтр недоступен.',
    'processor-unavailable' => 'Нативный фильтр недоступен.',
    'awaiting-audio' => 'Ожидаем аудио от микрофона.',
    null || '' => '',
    _ => 'Ошибка аудиофильтра.',
  };

  static bool _requestMatches(
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) => runtime.requestedMode == requestedMode;

  static bool _rnnoiseConfirmed(
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) =>
      _requestMatches(runtime, requestedMode) &&
      requestedMode == NoiseSuppressionMode.rnnoise &&
      runtime.status == 'active' &&
      runtime.effectiveMode == 'rnnoise' &&
      runtime.processedFrames > 0 &&
      (runtime.failureReason == null || runtime.failureReason!.isEmpty);

  static String _runtimeTitle(
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) {
    if (!_requestMatches(runtime, requestedMode)) {
      return 'Ожидание подтверждения настройки';
    }
    return switch (runtime.status) {
      'active' =>
        _rnnoiseConfirmed(runtime, requestedMode)
            ? 'RNNoise активен'
            : 'Обработка не подтверждена',
      'initializing' => 'Ожидание аудиопотока',
      'fallback' =>
        runtime.effectiveMode == 'browser'
            ? 'Стандартная обработка включена'
            : 'Резервный режим не подтверждён',
      'unsupported' => 'RNNoise недоступен',
      'error' => 'Обработка микрофона приостановлена',
      'idle' => 'Состояние не проверено',
      _ => 'Состояние неизвестно',
    };
  }

  static String _runtimeDetail(
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) {
    if (!_requestMatches(runtime, requestedMode)) {
      return 'Отчёт относится к предыдущему режиму; активность нового режима пока не подтверждена.';
    }
    return switch (runtime.status) {
      'active' =>
        _rnnoiseConfirmed(runtime, requestedMode)
            ? 'Нативный процессор подтвердил обработку ${runtime.processedFrames} кадров.'
            : 'Текущие данные не подтверждают активную обработку.',
      'initializing' =>
        runtime.failureReason == 'awaiting-audio'
            ? 'Первые обработанные кадры ещё не получены.'
            : 'Режим не будет считаться активным до подтверждения обработанных кадров.',
      'fallback' =>
        runtime.effectiveMode == 'browser'
            ? 'Нативный runtime сообщает о стандартной обработке вместо RNNoise.'
            : 'Нативный runtime не подтвердил, какой режим применяется.',
      'unsupported' =>
        runtime.effectiveMode == 'browser'
            ? 'RNNoise недоступен; runtime сообщает о стандартном режиме.'
            : 'RNNoise недоступен; применение резервного режима не подтверждено.',
      'error' => 'Отправка микрофона отключена до восстановления обработки.',
      'idle' => 'Работа фильтра ещё не проверена аудиокадрами.',
      _ => 'Не удалось определить режим по данным нативного runtime.',
    };
  }

  static IconData _runtimeIcon(
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) {
    if (!_requestMatches(runtime, requestedMode)) return Icons.sync;
    return switch (runtime.status) {
      'active' when _rnnoiseConfirmed(runtime, requestedMode) =>
        Icons.check_circle_outline,
      'initializing' => Icons.hourglass_top,
      'fallback' => Icons.swap_horiz,
      'unsupported' || 'error' => Icons.error_outline,
      'idle' => Icons.help_outline,
      _ => Icons.info_outline,
    };
  }

  static Color _runtimeColor(
    ColorScheme colors,
    NativeNoiseSuppressionState runtime,
    NoiseSuppressionMode requestedMode,
  ) {
    if (!_requestMatches(runtime, requestedMode)) {
      return colors.onSurfaceVariant;
    }
    return switch (runtime.status) {
      'active' when _rnnoiseConfirmed(runtime, requestedMode) =>
        colors.tertiary,
      'initializing' || 'fallback' => colors.primary,
      'unsupported' || 'error' => colors.error,
      _ => colors.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    final colors = Theme.of(context).colorScheme;
    final requestedMode = processing.noiseSuppressionMode;
    final runtimeTitle = _runtimeTitle(runtime, requestedMode);
    final runtimeDetail = _runtimeDetail(runtime, requestedMode);
    final requestMatches = _requestMatches(runtime, requestedMode);
    final reasonText = requestMatches ? reason(runtime.failureReason) : '';
    final statusColor = _runtimeColor(colors, runtime, requestedMode);
    final showRuntimeStatus =
        (requestedMode == NoiseSuppressionMode.rnnoise &&
            runtime.status != 'idle') ||
        (_requestMatches(runtime, requestedMode) && runtime.status == 'error');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<NoiseSuppressionMode>(
          key: ValueKey(processing.noiseSuppressionMode),
          initialValue: processing.noiseSuppressionMode,
          isExpanded: true,
          selectedItemBuilder: (context) => [
            for (final mode in NoiseSuppressionMode.values)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  switch (mode) {
                    NoiseSuppressionMode.off => 'Выключено',
                    NoiseSuppressionMode.browser =>
                      compact ? 'WebRTC' : label(mode.name),
                    NoiseSuppressionMode.rnnoise =>
                      compact ? 'RNNoise' : 'RNNoise — экспериментальное',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          decoration: const InputDecoration(labelText: 'Шумоподавление'),
          items: [
            for (final mode in NoiseSuppressionMode.values)
              DropdownMenuItem(
                value: mode,
                enabled:
                    mode != NoiseSuppressionMode.rnnoise ||
                    runtime.status != 'unsupported',
                child: Text(
                  mode == NoiseSuppressionMode.rnnoise
                      ? 'RNNoise — экспериментальное'
                      : label(mode.name),
                ),
              ),
          ],
          onChanged: (mode) {
            if (mode != null) {
              onChanged(processing.copyWith(noiseSuppressionMode: mode));
            }
          },
        ),
        if (showRuntimeStatus) ...[
          const SizedBox(height: 8),
          Semantics(
            key: const ValueKey('noise-suppression-runtime-status'),
            container: true,
            liveRegion: true,
            label: runtimeTitle,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(
                    _runtimeIcon(runtime, requestedMode),
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      runtimeTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ExpansionTile(
          title: const Text('Сведения об обработке'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: 12,
          ),
          children: [
            Text(runtimeDetail),
            if (reasonText.isNotEmpty) Text(reasonText),
            Text(
              requestMatches
                  ? 'Состояние: $runtimeTitle; обработано кадров: ${runtime.processedFrames}; резервных кадров: ${runtime.fallbackFrames}.'
                  : 'Состояние: $runtimeTitle.',
            ),
            if (requestMatches)
              Text('Нативный отчёт о режиме: ${label(runtime.effectiveMode)}.'),
            if (requestMatches &&
                runtime.sampleRate != null &&
                runtime.sampleRate! > 0 &&
                runtime.channels != null &&
                runtime.channels! > 0)
              Text(
                'PCM: ${runtime.sampleRate} Гц; каналы: ${runtime.channels}.',
              ),
            if (_rnnoiseConfirmed(runtime, requestedMode))
              const Text(
                'Модель RNNoise: rnnoise-stock-v0.1. Время инициализации нативного DSP: недоступно.',
              ),
            const Text('Эти данные не оценивают качество звука.'),
          ],
        ),
      ],
    );
  }
}
