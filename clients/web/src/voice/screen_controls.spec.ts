import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createScreenControls, type ScreenShareState } from './screen_controls'
import { unknownScreenDiagnostics } from './screen_diagnostics'

describe('screen controls', () => {
  it('does not overlap periodic screen measurements', async () => {
    let finishRead: ((value: ReturnType<typeof unknownScreenDiagnostics>) => void) | undefined
    const session = {
      readScreenDiagnostics: vi.fn(() => new Promise<ReturnType<typeof unknownScreenDiagnostics>>((resolve) => { finishRead = resolve })),
      startScreen: vi.fn(), stopScreen: vi.fn(),
    }
    const controls = createScreenControls(session, ref({}), ref(null), ref(null), ref<ScreenShareState>('SHARING'), ref(unknownScreenDiagnostics()))

    const first = controls.refreshScreenDiagnostics()
    await controls.refreshScreenDiagnostics()
    expect(session.readScreenDiagnostics).toHaveBeenCalledOnce()
    finishRead?.(unknownScreenDiagnostics())
    await first
  })

  it('keeps screen sharing active while warning that the browser supplied no audio track', async () => {
    const screenDiagnostics = ref(unknownScreenDiagnostics())
    const screenError = ref<string | null>(null)
    const screenProfile = ref(null)
    const screenState = ref<'IDLE' | 'STARTING' | 'SHARING' | 'STOPPING' | 'ERROR'>('IDLE')
    const session = {
      readScreenDiagnostics: vi.fn(),
      startScreen: vi.fn().mockResolvedValue({ audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' }),
      stopScreen: vi.fn(),
    }
    const controls = createScreenControls(session, ref({}), screenError, screenProfile, screenState, screenDiagnostics)

    await controls.startScreen('P1080_60')

    expect(screenDiagnostics.value.audioTrack).toBe('ABSENT')
    expect(screenError.value).toContain('без аудиодорожки')
    expect(screenState.value).toBe('SHARING')
  })

  it('changes the active profile without starting a second capture', async () => {
    const profile = ref<'P720_15' | 'P1080_30' | null>('P720_15')
    const state = ref<ScreenShareState>('SHARING')
    const session = {
      readScreenDiagnostics: vi.fn(), startScreen: vi.fn(), stopScreen: vi.fn(),
      updateScreenProfile: vi.fn().mockResolvedValue(unknownScreenDiagnostics()),
    }
    const controls = createScreenControls(session, ref({}), ref(null), profile, state, ref(unknownScreenDiagnostics()))

    await controls.startScreen('P1080_30')

    expect(session.updateScreenProfile).toHaveBeenCalledWith('P1080_30')
    expect(session.startScreen).not.toHaveBeenCalled()
    expect(state.value).toBe('SHARING')
    expect(profile.value).toBe('P1080_30')
  })

  it('clears a finished source after an explicit measurement refresh', async () => {
    const screenDiagnostics = ref(unknownScreenDiagnostics())
    const screenError = ref<string | null>(null)
    const screenProfile = ref(null)
    const screenState = ref<'IDLE' | 'STARTING' | 'SHARING' | 'STOPPING' | 'ERROR'>('IDLE')
    const session = {
      readScreenDiagnostics: vi.fn().mockResolvedValue({ audioTrack: 'PRESENT', connectionQuality: 'LOST', measured: null, source: 'ENDED' }),
      startScreen: vi.fn().mockResolvedValue({ audioTrack: 'PRESENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' }),
      stopScreen: vi.fn(),
    }
    const controls = createScreenControls(session, ref({}), screenError, screenProfile, screenState, screenDiagnostics)

    await controls.startScreen('P720_30')
    await controls.refreshScreenDiagnostics()

    expect(screenDiagnostics.value.source).toBe('UNKNOWN')
    expect(screenError.value).toBeNull()
    expect(screenState.value).toBe('IDLE')
    expect(screenProfile.value).toBeNull()
    expect(session.stopScreen).toHaveBeenCalledOnce()
  })

  it('treats the browser ending capture as a normal stop, including while a read is pending', async () => {
    const screenDiagnostics = ref(unknownScreenDiagnostics())
    const screenError = ref<string | null>(null)
    const screenProfile = ref<'P720_30' | null>(null)
    const screenState = ref<ScreenShareState>('IDLE')
    const listeners = new Set<() => void>()
    let rejectRead: ((reason: unknown) => void) | undefined
    const session = {
      readScreenDiagnostics: vi.fn(() => new Promise<ReturnType<typeof unknownScreenDiagnostics>>((_resolve, reject) => {
        rejectRead = reject
      })),
      startScreen: vi.fn().mockResolvedValue({ audioTrack: 'PRESENT', connectionQuality: 'GOOD', measured: null, source: 'ACTIVE' }),
      stopScreen: vi.fn(),
      onScreenEnded(listener: () => void) { listeners.add(listener); return () => listeners.delete(listener) },
    }
    const controls = createScreenControls(session, ref({}), screenError, screenProfile, screenState, screenDiagnostics)

    await controls.startScreen('P720_30')
    const refresh = controls.refreshScreenDiagnostics()
    for (const listener of [...listeners]) listener()
    rejectRead?.(new Error('capture already ended'))
    await refresh

    expect(screenState.value).toBe('IDLE')
    expect(screenProfile.value).toBeNull()
    expect(screenDiagnostics.value.source).toBe('UNKNOWN')
    expect(screenError.value).toBeNull()
  })
})
