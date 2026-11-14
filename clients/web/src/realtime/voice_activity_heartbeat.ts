const voiceActivityHeartbeatIntervalMs = 5_000

export function startVoiceActivityHeartbeat(
  isSpeaking: () => boolean,
  reportActivity: () => void,
  intervalMs = voiceActivityHeartbeatIntervalMs,
): () => void {
  const timer = setInterval(() => {
    if (isSpeaking()) reportActivity()
  }, intervalMs)
  return () => clearInterval(timer)
}
