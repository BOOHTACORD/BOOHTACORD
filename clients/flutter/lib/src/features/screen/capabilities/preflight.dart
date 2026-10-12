import 'package:flutter/foundation.dart';

/// Source implementation support, not a hardware acceptance result. No capture
/// or permission request occurs here; returned tracks remain authoritative.
class ScreenPreflight {
  const ScreenPreflight({
    required this.captureConfigured,
    required this.captureAudioConfigured,
    required this.videoLabel,
    required this.audioLabel,
    required this.viewerLabel,
  });
  final bool captureConfigured;
  final bool captureAudioConfigured;
  final String videoLabel, audioLabel, viewerLabel;
  static ScreenPreflight detect({
    required TargetPlatform platform,
    bool web = false,
    bool selecting = false,
    bool sourceAvailable = false,
    bool sourceError = false,
  }) {
    final supported =
        !web &&
        {
          TargetPlatform.linux,
          TargetPlatform.windows,
          TargetPlatform.macOS,
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(platform);
    final video = !supported
        ? 'Захват экрана недоступен на этой платформе.'
        : platform == TargetPlatform.iOS
        ? 'Видео: только содержимое BOOHTACORD; разрешение проверяется при запуске.'
        : selecting && sourceError
        ? 'Видео: список источников недоступен. Повторите загрузку.'
        : selecting && !sourceAvailable
        ? 'Видео: проверяем доступные экраны и окна.'
        : selecting
        ? 'Видео: доступные экраны и окна; системное разрешение проверяется при запуске.'
        : 'Видео: системный выбор источника и разрешение при запуске.';
    final audio = !supported
        ? 'Звук экрана на этой платформе недоступен.'
        : switch (platform) {
            TargetPlatform.windows => 'Windows: запрашивается loopback-аудио выбранного источника; доступность зависит от источника и системы.',
            TargetPlatform.linux => 'Linux: запрашивается аудио через PulseAudio/PipeWire; нужен собранный loopback backend.',
            TargetPlatform.macOS => 'macOS 13+: запрашивается аудио через ScreenCaptureKit; потребуется разрешение записи экрана.',
            TargetPlatform.android => 'Android 10+: понадобится разрешение записи аудио; приложение-источник может запретить захват.',
            TargetPlatform.iOS => 'iOS: звук передаётся через системный ReplayKit broadcast; приложение-источник может ограничить захват.',
            _ => 'Звук экрана на этой платформе недоступен.',
          };
    return ScreenPreflight(
      captureConfigured: supported && !sourceError,
      captureAudioConfigured: supported,
      videoLabel: video,
      audioLabel: audio,
      viewerLabel:
          'Просмотр чужой демонстрации и голосовой канал остаются доступны.',
    );
  }
}
