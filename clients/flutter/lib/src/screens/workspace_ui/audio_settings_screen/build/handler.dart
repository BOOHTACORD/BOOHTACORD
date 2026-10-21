import 'device_selection/handler.dart';
import 'voice_shortcuts/handler.dart';
import 'microphone_processing/handler.dart';
import 'microphone_activation/handler.dart';
import '../../audio_device_shown_by_dropdown/component.dart';
import '../../audio_settings_card/component.dart';
import '../../header/component.dart';
import '../../native_bindings.dart';
import '../../../../widgets/noise_suppression_settings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceAudioSettingsScreenBuildBinding
    on WorkspaceAudioSettingsScreenContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceAudioSettingsScreenBuild(context);
  }
}

extension WorkspaceAudioSettingsScreenBuildAction
    on WorkspaceAudioSettingsScreenContext {
  Widget executeWorkspaceAudioSettingsScreenBuild(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < GcLayout.mobileBreakpoint;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final inputDevice = workspaceAudioDeviceShownByDropdown(
            state.audioInputDevices,
            state.selectedAudioInputId,
          );
          final outputDevice = workspaceAudioDeviceShownByDropdown(
            state.audioOutputDevices,
            state.selectedAudioOutputId,
          );
          return Column(
            children: [
              WorkspaceHeader(
                icon: Icons.tune,
                title: 'Настройки аудио',
                subtitle: compact
                    ? ''
                    : 'Проверьте устройства перед разговором.',
                onBack: compact ? onBack : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Обновить список устройств',
                      onPressed: state.audioDevicesLoading
                          ? null
                          : state.refreshAudioDevices,
                      icon: state.audioDevicesLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: 'Закрыть настройки аудио',
                        onPressed: onBack,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('audio-settings-list'),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 24,
                    compact ? 24 : 32,
                    compact ? 16 : 24,
                    compact ? 48 : 32,
                  ),
                  children: [
                    if (compact) ...[
                      const Text(
                        'Проверьте устройства перед разговором.',
                        key: ValueKey('audio-settings-intro'),
                        style: TextStyle(
                          color: GcColors.muted,
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    renderAudioSettingsScreenDeviceSelection(
                      compact,
                      inputDevice,
                      outputDevice,
                    ),
                    renderAudioSettingsScreenMicrophoneActivation(compact),
                    if (const [
                      'fallback',
                      'error',
                      'unsupported',
                    ].contains(state.noiseSuppressionRuntime.status))
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            state.noiseSuppressionRuntime.requestedMode !=
                                    state.audioProcessing.noiseSuppressionMode
                                ? 'Ожидание подтверждения настройки обработки микрофона.'
                                : 'Обработка микрофона: ${NoiseSuppressionSettings.label(state.noiseSuppressionRuntime.effectiveMode)}. '
                                      '${NoiseSuppressionSettings.reason(state.noiseSuppressionRuntime.failureReason)}',
                            style: const TextStyle(color: GcColors.warning),
                          ),
                        ),
                      ),
                    ExpansionTile(
                      key: const PageStorageKey('audio-settings-advanced'),
                      title: const Text('Дополнительно'),
                      subtitle: const Text(
                        'Обработка микрофона, сочетания клавиш и диагностика',
                      ),
                      tilePadding: EdgeInsets.zero,
                      maintainState: true,
                      children: [
                        if (!state.usesTouchPushToTalk ||
                            hardwareKeyboardAvailable)
                          renderAudioSettingsScreenVoiceShortcuts(compact),
                        renderAudioSettingsScreenMicrophoneProcessing(compact),
                      ],
                    ),
                    WorkspaceAudioSettingsCard(
                      cardKey: const ValueKey('audio-settings-playback-card'),
                      title: 'Воспроизведение',
                      subtitle: 'Громкость участников и демонстраций на этом устройстве.',
                      compact: compact,
                      child: AudioVolumeReset(
                        reset: state.resetAudioVolumes,
                        warning: state.voiceVolumeWarning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
