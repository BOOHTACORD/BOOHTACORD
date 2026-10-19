import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'
import { ref } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'

import VoiceDock from './VoiceDock.vue'
import { createScreenControls } from './screen_controls'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import { browserScreenCaptureCapabilities, observedScreenCaptureTracks } from './screen_capture_capabilities'
import { screenFailureMessage } from './screen_feedback'

afterEach(() => vi.unstubAllGlobals())

describe('browser screen capture availability', () => {
  it('explains unsupported Android Chrome before opening a nonexistent chooser', async () => {
    const androidChrome = 'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/152.0 Mobile Safari/537.36'
    const androidUnavailableMessage = 'В браузере Android нельзя начать трансляцию экрана. Откройте приложение BOOHTACORD.'
    expect(screenCaptureSupported(androidChrome, { getDisplayMedia: vi.fn() })).toBe(false)
    expect(screenCaptureUnavailableMessage(androidChrome)).toBe(androidUnavailableMessage)
    expect(screenFailureMessage(Object.assign(new Error('getDisplayMedia not supported'), { name: 'DeviceUnsupportedError' }), androidChrome)).toBe(androidUnavailableMessage)

    vi.stubGlobal('navigator', { userAgent: androidChrome, mediaDevices: {} })
    const html = await renderToString(createSSRApp(VoiceDock, {
      channel: { id: 'voice', name: 'Voice', kind: 'VOICE', position: 0 }, activeSession: true,
      error: null, activationMode: 'VAD', deafened: false, deafenChanging: false,
      microphoneMuted: true, microphonePermissionDenied: false, state: 'CONNECTED',
    }))
    expect(html).toMatch(/aria-label="[^"]*Откройте приложение BOOHTACORD[^"]*"[^>]* disabled/)
  })

  it('allows browsers that expose display capture outside unsupported mobile Chrome', () => {
    expect(screenCaptureSupported('Mozilla/5.0 (Windows NT 10.0) Chrome/152.0', { getDisplayMedia: vi.fn() })).toBe(true)
    expect(screenCaptureSupported('Mozilla/5.0 (Windows NT 10.0) Chrome/152.0', undefined)).toBe(false)
  })

  it('keeps browser preflight distinct from selected sources and observed tracks', () => {
    expect(browserScreenCaptureCapabilities('Mozilla/5.0 (Windows NT 10.0) Chrome/152.0', { getDisplayMedia: vi.fn() }))
      .toEqual({ viewer: 'available', video: 'available', audio: 'unknown', sourceSelected: false })
    expect(observedScreenCaptureTracks({ videoTrack: true, audioTrack: false }))
      .toEqual({ video: 'present', audio: 'absent', sourceSelected: true })
  })

  it('keeps viewer and voice available when Android Chrome cannot start browser capture', () => {
    expect(browserScreenCaptureCapabilities('Mozilla/5.0 (Linux; Android 16) Chrome/152.0', { getDisplayMedia: vi.fn() }))
      .toEqual({ viewer: 'available', video: 'unavailable', audio: 'unknown', sourceSelected: false })
  })

  it('treats picker cancellation as an idle outcome instead of a capture error', async () => {
    const state = ref<'IDLE' | 'STARTING' | 'SHARING' | 'STOPPING' | 'ERROR'>('IDLE')
    const screenError = ref<string | null>(null)
    const screenProfile = ref<'P1080_30' | null>(null)
    const session = {
      readScreenDiagnostics: vi.fn(), stopScreen: vi.fn(),
      startScreen: vi.fn().mockRejectedValue(Object.assign(new Error('dismissed'), { name: 'AbortError' })),
    }
    const controls = createScreenControls(session, ref({}), screenError, screenProfile, state, ref({
      audioTrack: 'UNKNOWN', connectionQuality: 'UNKNOWN', measured: null, source: 'UNKNOWN',
    }))

    await controls.startScreen('P1080_30')

    expect(state.value).toBe('IDLE')
    expect(screenError.value).toBeNull()
    expect(screenProfile.value).toBeNull()
  })
})
