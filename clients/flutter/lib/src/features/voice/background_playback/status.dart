import '../lifecycle/types.dart';

String voicePlaybackWorkspaceStatus(
  VoicePhase phase, {
  required bool backgroundPlaybackUnavailable,
}) {
  if (backgroundPlaybackUnavailable &&
      (phase == VoicePhase.connected || phase == VoicePhase.listener)) {
    return 'Фоновое воспроизведение недоступно · вернитесь в приложение';
  }
  return switch (phase) {
    VoicePhase.joining => 'Подключаемся к голосовому каналу',
    VoicePhase.reconnecting => 'Восстанавливаем голосовое соединение',
    VoicePhase.leaving => 'Завершаем голосовое подключение',
    VoicePhase.connected || VoicePhase.listener => 'Голос подключён',
    _ => 'В голосовом канале',
  };
}
