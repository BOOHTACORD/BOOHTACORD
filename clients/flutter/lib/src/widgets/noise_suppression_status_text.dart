part of 'noise_suppression_settings.dart';

class _NoiseStatusText {
  static String label(String mode) => switch (mode) {
    'off' => 'Выключено',
    'browser' => 'Стандартное — WebRTC',
    'rnnoise' => 'RNNoise',
    'deepfilter' => 'DeepFilterNet3',
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
    'awaiting-model' => 'Подготавливаем модель шумоподавления.',
    'model-timeout' => 'Модель не успела подготовиться.',
    'processor-failed' => 'Не удалось запустить аудиофильтр.',
    'processor-underrun' => 'Аудиофильтр не успевает обработать звук.',
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
      (requestedMode == NoiseSuppressionMode.rnnoise ||
          requestedMode == NoiseSuppressionMode.deepfilter) &&
      runtime.status == 'active' &&
      runtime.effectiveMode == requestedMode.name &&
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
            ? '${label(requestedMode.name)} активен'
            : 'Обработка не подтверждена',
      'initializing' => 'Ожидание аудиопотока',
      'fallback' =>
        runtime.effectiveMode == 'browser'
            ? 'Стандартная обработка включена'
            : 'Резервный режим не подтверждён',
      'unsupported' => '${label(requestedMode.name)} недоступен',
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
            ? 'Нативный runtime сообщает о стандартной обработке вместо ${label(requestedMode.name)}.'
            : 'Нативный runtime не подтвердил, какой режим применяется.',
      'unsupported' =>
        runtime.effectiveMode == 'browser'
            ? '${label(requestedMode.name)} недоступен; runtime сообщает о стандартном режиме.'
            : '${label(requestedMode.name)} недоступен; применение резервного режима не подтверждено.',
      'error' => 'Отправка микрофона отключена до восстановления обработки.',
      'idle' => 'Работа фильтра ещё не проверена аудиокадрами.',
      _ => 'Не удалось определить режим по данным нативного runtime.',
    };
  }
}
