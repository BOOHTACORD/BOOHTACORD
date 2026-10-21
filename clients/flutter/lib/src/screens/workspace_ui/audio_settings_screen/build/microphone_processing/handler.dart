import '../../../audio_settings_card/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AudioSettingsScreenMicrophoneProcessingRenderer
    on WorkspaceAudioSettingsScreenContext {
  WorkspaceAudioSettingsCard renderAudioSettingsScreenMicrophoneProcessing(
    bool compact,
  ) => WorkspaceAudioSettingsCard(
    cardKey: const ValueKey('audio-settings-processing-card'),
    title: 'Обработка микрофона',
    subtitle: 'Автоматическая обработка и усиление сигнала микрофона.',
    compact: compact,
    minHeight: compact ? 224 : 236,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Автоматическая регулировка усиления'),
          value: state.audioProcessing.autoGainControl,
          onChanged: (value) => state.setAudioProcessing(
            state.audioProcessing.copyWith(autoGainControl: value),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Подавление эха'),
          value: state.audioProcessing.echoCancellation,
          onChanged: (value) => state.setAudioProcessing(
            state.audioProcessing.copyWith(echoCancellation: value),
          ),
        ),
        MicrophoneControl(
          settings: state.microphoneSettings,
          runtime: state.microphoneControlsRuntime,
          onChanged: state.updateMicrophoneSettings,
          sensitivity: false,
          vad: state.audioActivationMode == AudioActivationMode.vad,
          agc: state.audioProcessing.autoGainControl,
        ),
        AudioProcessingAdvancedSettings(
          inline: true,
          processing: state.audioProcessing,
          runtime: state.noiseSuppressionRuntime,
          onProcessingChanged: state.setAudioProcessing,
          voiceConnected:
              state.voicePhase != VoicePhase.idle &&
              state.voicePhase != VoicePhase.error,
          voiceDiagnostics: state.voiceAudioDiagnostics,
        ),
      ],
    ),
  );
}
