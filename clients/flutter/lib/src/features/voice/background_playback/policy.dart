bool shouldKeepVoicePlaybackForeground({
  required bool isAndroid,
  required bool voiceActive,
  required bool deafened,
}) => isAndroid && voiceActive && !deafened;
