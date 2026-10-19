import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ref } from 'vue'

const voice = vi.hoisted(() => ({
  active: { listenerOnly: false } as { listenerOnly: boolean } | null,
  microphoneMuted: false,
  microphonePermissionDenied: false,
  deafened: false,
  state: 'CONNECTED',
  setMicrophoneMuted: vi.fn(),
}))

vi.mock('../connection_store', () => ({ useVoiceConnectionStore: () => voice }))
import { createPttActivation } from './ptt'

describe('touch push-to-talk activation', () => {
  beforeEach(() => {
    voice.active = { listenerOnly: false }
    voice.microphoneMuted = false
    voice.microphonePermissionDenied = false
    voice.deafened = false
    voice.state = 'CONNECTED'
    voice.setMicrophoneMuted.mockReset().mockImplementation(async (muted: boolean) => {
      voice.microphoneMuted = muted
      if (!muted && voice.active) voice.active.listenerOnly = false
    })
  })

  it('starts without a key on touch and unmutes only while pressed', async () => {
    const error = ref<string | null>(null)
    const activation = createPttActivation(ref<string | null>(null), error, ref(true))

    await activation.start()
    expect(error.value).toBeNull()
    expect(voice.microphoneMuted).toBe(true)

    await activation.setTouchPressed(true)
    expect(voice.microphoneMuted).toBe(false)
    await activation.setTouchPressed(false)
    expect(voice.microphoneMuted).toBe(true)

    await activation.stop()
    expect(voice.microphoneMuted).toBe(false)
  })

  it('still requires a keyboard binding on non-touch devices', async () => {
    const error = ref<string | null>(null)
    const activation = createPttActivation(ref<string | null>(null), error, ref(false))

    await activation.start()
    expect(error.value).toBe('Для push-to-talk назначьте клавишу.')
    await activation.setTouchPressed(true)
    expect(voice.microphoneMuted).toBe(true)
    await activation.stop(false)
  })

  it('does not unmute when the touch session cannot publish audio', async () => {
    voice.state = 'LISTENER'
    const error = ref<string | null>(null)
    const activation = createPttActivation(ref<string | null>(null), error, ref(true))

    await activation.start()
    await activation.setTouchPressed(true)
    expect(voice.microphoneMuted).toBe(true)
    await activation.stop(false)
  })

  it('starts publishing from a listener-only PTT session only while touch is held', async () => {
    voice.state = 'LISTENER'
    voice.active = { listenerOnly: true }
    const error = ref<string | null>(null)
    const activation = createPttActivation(ref<string | null>(null), error, ref(true))

    await activation.start()
    await activation.setTouchPressed(true)
    expect(voice.microphoneMuted).toBe(false)
    expect(voice.active.listenerOnly).toBe(false)

    await activation.setTouchPressed(false)
    expect(voice.microphoneMuted).toBe(true)
    await activation.stop(false)
  })
})
