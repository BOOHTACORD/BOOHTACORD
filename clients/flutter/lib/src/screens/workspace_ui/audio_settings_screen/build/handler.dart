import 'dart:io' show Platform;

import 'device_selection/handler.dart';
import 'voice_shortcuts/handler.dart';
import 'microphone_processing/handler.dart';
import 'microphone_activation/handler.dart';
import '../../audio_device_shown_by_dropdown/component.dart';
import '../../audio_settings_card/component.dart';
import '../../header/component.dart';
import '../../native_bindings.dart';
import '../../../../widgets/audio_processing_advanced_settings.dart';

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
                subtitle: '',
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final useTwoColumns =
                        MediaQuery.sizeOf(context).width >=
                        GcLayout.mobileBreakpoint;
                    final cards = <Widget>[
                      renderAudioSettingsScreenDeviceSelection(
                        compact,
                        inputDevice,
                        outputDevice,
                      ),
                      renderAudioSettingsScreenMicrophoneActivation(compact),
                      if (!state.usesTouchPushToTalk ||
                          hardwareKeyboardAvailable)
                        renderAudioSettingsScreenVoiceShortcuts(compact),
                      renderAudioSettingsScreenMicrophoneProcessing(compact),
                    ];
                    final content = useTwoColumns
                        ? Wrap(
                            spacing: 20,
                            children: [
                              for (final card in cards)
                                SizedBox(
                                  width: (constraints.maxWidth - 20) / 2,
                                  child: card,
                                ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: cards,
                          );
                    return ListView(
                      key: const ValueKey('audio-settings-list'),
                      padding: EdgeInsets.fromLTRB(
                        compact ? 16 : 24,
                        compact ? 24 : 32,
                        compact ? 16 : 24,
                        compact ? 48 : 32,
                      ),
                      children: [
                        content,
                        WorkspaceAudioSettingsCard(
                          cardKey: const ValueKey(
                            'audio-settings-playback-card',
                          ),
                          title: 'Воспроизведение',
                          subtitle: 'Громкость участников и демонстраций на этом устройстве.',
                          compact: compact,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AudioVolumeReset(
                                reset: state.resetAudioVolumes,
                                warning: state.voiceVolumeWarning,
                              ),
                              if (Platform.isWindows) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Если при входе в голосовой канал Windows уменьшает '
                                  'громкость музыки и других приложений: '
                                  'Панель управления → Звук → Связь → '
                                  '«Действие не требуется». '
                                  'Это системная настройка, BOOHTACORD '
                                  'не изменяет её автоматически.',
                                  style: TextStyle(
                                    color: GcColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        WorkspaceAudioSettingsCard(
                          cardKey: const ValueKey(
                            'audio-settings-diagnostics-card',
                          ),
                          title: 'Диагностика',
                          subtitle: 'Технические сведения доступны по запросу.',
                          compact: compact,
                          child: AudioProcessingAdvancedSettings(
                            voiceConnected:
                                state.voicePhase != VoicePhase.idle &&
                                state.voicePhase != VoicePhase.error,
                            voiceDiagnostics: state.voiceAudioDiagnostics,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
