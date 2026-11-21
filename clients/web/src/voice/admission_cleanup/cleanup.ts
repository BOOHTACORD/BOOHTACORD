import type { ActiveVoiceSession } from '../voice_session_types'
import type { VoiceDeafen } from '../voice_deafen'
import type { VoiceScreenSession } from '../voice_screen_session'

interface CleanupState {
  current(): ActiveVoiceSession | null
  setCurrent(value: ActiveVoiceSession | null): void
  stopInputSelection(): (() => void) | undefined
  setStopInputSelection(value?: () => void): void
  screen: Pick<VoiceScreenSession, 'cancel'>
  deafen: Pick<VoiceDeafen, 'reset'>
}

export async function cleanupFailedVoiceJoin(
  state: CleanupState,
  room: ActiveVoiceSession['room'] | null,
  release: () => Promise<void>,
): Promise<void> {
  if (room && state.current()?.room === room) {
    state.setCurrent(null)
    try { state.stopInputSelection()?.() } catch { /* Continue local teardown. */ }
    state.setStopInputSelection(undefined)
    try { state.screen.cancel() } catch { /* Continue local teardown. */ }
    try { state.deafen.reset() } catch { /* Continue local teardown. */ }
  }
  try { await room?.stopScreenPreview?.() } catch { /* Disconnect and release still follow. */ }
  try { await room?.disconnect() } catch { /* Preserve the original join failure. */ }
  try { await release() } catch { /* Preserve the original join failure. */ }
}
