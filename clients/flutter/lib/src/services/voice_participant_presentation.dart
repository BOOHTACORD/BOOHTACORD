class VoiceParticipantPresentation {
  const VoiceParticipantPresentation._({
    required this.isSpeaking,
    required this.label,
  });

  final bool isSpeaking;
  final String label;

  factory VoiceParticipantPresentation.resolve({
    bool muted = false,
    bool microphoneUnavailable = false,
    bool deafened = false,
    bool speaking = false,
  }) {
    final isSpeaking =
        speaking && !muted && !microphoneUnavailable && !deafened;
    final label = deafened
        ? 'Не слышит участников'
        : microphoneUnavailable
        ? 'Микрофон недоступен'
        : muted
        ? 'Микрофон выключен'
        : isSpeaking
        ? 'Говорит'
        : 'В канале';
    return VoiceParticipantPresentation._(isSpeaking: isSpeaking, label: label);
  }
}
