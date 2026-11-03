export type VoiceViewSelection = { id: string; isLocal: boolean } | null
export type VoiceViewTransitionSound = 'stream-view-started' | 'stream-view-stopped'

export function voiceViewTransitionSound(
  previous: VoiceViewSelection,
  next: VoiceViewSelection,
): VoiceViewTransitionSound | null {
  const wasWatchingRemote = Boolean(previous && !previous.isLocal)
  const willWatchRemote = Boolean(next && !next.isLocal)
  if (!wasWatchingRemote && willWatchRemote) return 'stream-view-started'
  if (wasWatchingRemote && !willWatchRemote) return 'stream-view-stopped'
  return null
}
