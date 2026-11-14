enum NoiseSuppressionMode { off, browser, rnnoise, deepfilter, auto }

class AudioProcessingPreferences {
  const AudioProcessingPreferences({
    this.autoGainControl = true,
    this.echoCancellation = true,
    NoiseSuppressionMode? noiseSuppressionMode,
    bool? noiseSuppression,
  }) : noiseSuppressionMode =
           noiseSuppressionMode ??
           (noiseSuppression == false
               ? NoiseSuppressionMode.off
               : NoiseSuppressionMode.browser);

  final bool autoGainControl;
  final bool echoCancellation;
  final NoiseSuppressionMode noiseSuppressionMode;
  bool get noiseSuppression =>
      noiseSuppressionMode == NoiseSuppressionMode.browser ||
      noiseSuppressionMode == NoiseSuppressionMode.auto;

  AudioProcessingPreferences copyWith({
    bool? autoGainControl,
    bool? echoCancellation,
    bool? noiseSuppression,
    NoiseSuppressionMode? noiseSuppressionMode,
  }) => AudioProcessingPreferences(
    autoGainControl: autoGainControl ?? this.autoGainControl,
    echoCancellation: echoCancellation ?? this.echoCancellation,
    noiseSuppressionMode:
        noiseSuppressionMode ??
        (noiseSuppression == null
            ? this.noiseSuppressionMode
            : noiseSuppression
            ? NoiseSuppressionMode.browser
            : NoiseSuppressionMode.off),
  );

  Map<String, Object> toJson() => {
    'autoGainControl': autoGainControl,
    'echoCancellation': echoCancellation,
    'noiseSuppressionMode': noiseSuppressionMode.name,
  };

  factory AudioProcessingPreferences.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const AudioProcessingPreferences();
    }
    return AudioProcessingPreferences(
      autoGainControl: value['autoGainControl'] is bool
          ? value['autoGainControl'] as bool
          : true,
      echoCancellation: value['echoCancellation'] is bool
          ? value['echoCancellation'] as bool
          : true,
      noiseSuppressionMode: NoiseSuppressionMode.values
          .where((mode) => mode.name == value['noiseSuppressionMode'])
          .firstOrNull,
      noiseSuppression: value['noiseSuppression'] is bool
          ? value['noiseSuppression'] as bool
          : true,
    );
  }
}
