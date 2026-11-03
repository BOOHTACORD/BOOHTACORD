import 'package:flutter/material.dart';

import '../features/voice/audio_diagnostics/model.dart';
import 'voice_audio_diagnostics/control.dart';

/// Detailed connection statistics, kept out of the everyday settings flow.
class AudioProcessingAdvancedSettings extends StatelessWidget {
  const AudioProcessingAdvancedSettings({
    super.key,
    required this.voiceConnected,
    required this.voiceDiagnostics,
  });

  final bool voiceConnected;
  final VoiceAudioDiagnostics? voiceDiagnostics;

  @override
  Widget build(BuildContext context) {
    return VoiceAudioDiagnosticsControl(
      connected: voiceConnected,
      diagnostics: voiceDiagnostics,
    );
  }
}
