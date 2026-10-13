import type { Ref } from 'vue'

import type { ScreenProfile } from './livekit_gateway'
import { ScreenPublisherOperationError } from './screen_publisher/adapter'
import { screenDiagnosticMessage, screenFailureMessage } from './screen_feedback'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'

export type ScreenShareState = 'IDLE' | 'STARTING' | 'SHARING' | 'STOPPING' | 'ERROR'
export interface ScreenSession {
  readScreenDiagnostics(): Promise<ScreenDiagnostics>
  startScreen(profile: ScreenProfile, mode?: 'motion' | 'text'): Promise<ScreenDiagnostics>
  updateScreenProfile?(profile: ScreenProfile, mode?: 'motion' | 'text'): Promise<ScreenDiagnostics>
  stopScreen(): Promise<void>
}

export function createScreenControls(
  session: ScreenSession,
  active: Ref<unknown | null>,
  screenError: Ref<string | null>,
  screenProfile: Ref<ScreenProfile | null>,
  screenState: Ref<ScreenShareState>,
  screenDiagnostics: Ref<ScreenDiagnostics>,
) {
  let refreshingDiagnostics = false
  async function startScreen(profile: ScreenProfile, mode?: 'motion' | 'text'): Promise<void> {
    if (!active.value || screenState.value === 'STARTING' || screenState.value === 'STOPPING') return
    if (screenState.value === 'SHARING') {
      try {
        if (!session.updateScreenProfile) throw new Error('Изменение качества во время трансляции недоступно.')
        screenDiagnostics.value = await (mode === undefined
          ? session.updateScreenProfile(profile) : session.updateScreenProfile(profile, mode))
        screenProfile.value = profile
        screenError.value = screenDiagnosticMessage(screenDiagnostics.value)
      } catch (cause) {
        screenError.value = screenFailureMessage(cause)
      }
      return
    }
    screenState.value = 'STARTING'
    screenError.value = null
    try {
      screenDiagnostics.value = await (mode === undefined
        ? session.startScreen(profile) : session.startScreen(profile, mode))
      screenProfile.value = profile
      screenState.value = 'SHARING'
      screenError.value = screenDiagnosticMessage(screenDiagnostics.value)
    } catch (cause) {
      if (captureCancelled(cause)) {
        if (screenState.value === 'STARTING') {
          screenDiagnostics.value = unknownScreenDiagnostics()
          screenProfile.value = null
          screenState.value = 'IDLE'
        }
        screenError.value = null
        return
      }
      screenState.value = 'ERROR'
      screenError.value = screenFailureMessage(cause)
    }
  }

  async function stopScreen(): Promise<void> {
    if (!active.value || screenState.value !== 'SHARING') return
    screenState.value = 'STOPPING'
    screenError.value = null
    try {
      await session.stopScreen()
      screenDiagnostics.value = unknownScreenDiagnostics()
      screenProfile.value = null
      screenState.value = 'IDLE'
    } catch (cause) {
      screenState.value = 'ERROR'
      screenError.value = screenFailureMessage(cause)
    }
  }

  async function refreshScreenDiagnostics(): Promise<void> {
    if (!active.value || screenState.value !== 'SHARING' || refreshingDiagnostics) return
    refreshingDiagnostics = true
    try {
      screenDiagnostics.value = await session.readScreenDiagnostics()
      screenError.value = screenDiagnosticMessage(screenDiagnostics.value)
      if (screenDiagnostics.value.source === 'ENDED') {
        await session.stopScreen()
        screenProfile.value = null
        screenState.value = 'IDLE'
      }
    } catch (cause) {
      screenError.value = screenFailureMessage(cause)
    } finally {
      refreshingDiagnostics = false
    }
  }

  return { refreshScreenDiagnostics, startScreen, stopScreen }
}

function captureCancelled(cause: unknown): boolean {
  return (cause instanceof Error && cause.name === 'AbortError')
    || (cause instanceof ScreenPublisherOperationError && cause.outcome === 'cancel')
}
