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
  onScreenEnded?(listener: () => void): () => void
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
  let operation = 0
  let stopScreenEnded: (() => void) | undefined

  function releaseScreenEnded(): void {
    stopScreenEnded?.()
    stopScreenEnded = undefined
  }

  function handleScreenEnded(): void {
    if (!['STARTING', 'SHARING', 'STOPPING', 'ERROR'].includes(screenState.value)) return
    ++operation
    releaseScreenEnded()
    screenDiagnostics.value = unknownScreenDiagnostics()
    screenProfile.value = null
    screenState.value = 'IDLE'
    screenError.value = null
  }

  function dispose(): void {
    ++operation
    releaseScreenEnded()
  }

  async function startScreen(profile: ScreenProfile, mode?: 'motion' | 'text'): Promise<void> {
    if (!active.value || screenState.value === 'STARTING' || screenState.value === 'STOPPING') return
    if (screenState.value === 'SHARING') {
      const currentOperation = operation
      try {
        if (!session.updateScreenProfile) throw new Error('Изменение качества во время трансляции недоступно.')
        const diagnostics = await (mode === undefined
          ? session.updateScreenProfile(profile) : session.updateScreenProfile(profile, mode))
        if (currentOperation !== operation || screenState.value !== 'SHARING') return
        screenDiagnostics.value = diagnostics
        screenProfile.value = profile
        screenError.value = screenDiagnosticMessage(screenDiagnostics.value)
      } catch (cause) {
        if (currentOperation !== operation || screenState.value !== 'SHARING') return
        screenError.value = screenFailureMessage(cause)
      }
      return
    }
    const currentOperation = ++operation
    releaseScreenEnded()
    screenState.value = 'STARTING'
    screenError.value = null
    stopScreenEnded = session.onScreenEnded?.(handleScreenEnded)
    try {
      const diagnostics = await (mode === undefined
        ? session.startScreen(profile) : session.startScreen(profile, mode))
      if (currentOperation !== operation || screenState.value !== 'STARTING') return
      screenDiagnostics.value = diagnostics
      screenProfile.value = profile
      screenState.value = 'SHARING'
      screenError.value = screenDiagnosticMessage(screenDiagnostics.value)
    } catch (cause) {
      if (currentOperation !== operation) return
      releaseScreenEnded()
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
    const currentOperation = ++operation
    screenState.value = 'STOPPING'
    screenError.value = null
    try {
      await session.stopScreen()
      if (currentOperation !== operation) return
      releaseScreenEnded()
      screenDiagnostics.value = unknownScreenDiagnostics()
      screenProfile.value = null
      screenState.value = 'IDLE'
    } catch (cause) {
      if (currentOperation !== operation) return
      screenState.value = 'ERROR'
      screenError.value = screenFailureMessage(cause)
    }
  }

  async function refreshScreenDiagnostics(): Promise<void> {
    if (!active.value || screenState.value !== 'SHARING' || refreshingDiagnostics) return
    const currentOperation = operation
    refreshingDiagnostics = true
    try {
      const diagnostics = await session.readScreenDiagnostics()
      if (currentOperation !== operation || screenState.value !== 'SHARING') return
      if (diagnostics.source === 'ENDED') {
        try { await session.stopScreen() } catch { /* the captured source has already ended */ }
        if (currentOperation !== operation) return
        screenDiagnostics.value = unknownScreenDiagnostics()
        screenError.value = null
        screenProfile.value = null
        screenState.value = 'IDLE'
        releaseScreenEnded()
        return
      }
      screenDiagnostics.value = diagnostics
      screenError.value = screenDiagnosticMessage(diagnostics)
    } catch (cause) {
      if (currentOperation !== operation || screenState.value !== 'SHARING') return
      screenError.value = screenFailureMessage(cause)
    } finally {
      refreshingDiagnostics = false
    }
  }

  return { dispose, refreshScreenDiagnostics, startScreen, stopScreen }
}

function captureCancelled(cause: unknown): boolean {
  return (cause instanceof Error && cause.name === 'AbortError')
    || (cause instanceof ScreenPublisherOperationError && cause.outcome === 'cancel')
}
