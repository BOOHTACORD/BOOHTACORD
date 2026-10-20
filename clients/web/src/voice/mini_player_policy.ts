export function miniPlayerVisible(voiceVisible: boolean, selectedId: string | null, activeVoiceChannelId: string | null): boolean {
  return !voiceVisible && Boolean(selectedId && activeVoiceChannelId)
}

export function screenViewerMounted(voiceVisible: boolean, selectedId: string | null, activeVoiceChannelId: string | null): boolean {
  return voiceVisible || miniPlayerVisible(voiceVisible, selectedId, activeVoiceChannelId)
}
