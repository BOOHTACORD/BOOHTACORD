import { watch, type Ref } from 'vue'
import { PushToTalk, type KeyboardInput } from '../push_to_talk'
import { useVoiceConnectionStore } from '../connection_store'

function browserEvents(): KeyboardInput {
  return {
    addEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).addEventListener(type, listener as unknown as EventListener),
    removeEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).removeEventListener(type, listener as unknown as EventListener),
  }
}

export function createPttActivation(pttKey: Ref<string | null>, error: Ref<string | null>, touchPttEnabled: Ref<boolean>) {
  let pushToTalk: PushToTalk | null = null
  let mutedBeforePtt: boolean | null = null
  let queuedChange: Promise<void> = Promise.resolve()
  let stopObserving = () => {}
  let keyboardPressed = false, touchPressed = false, sessionActive = false

  function queueMute(voice: ReturnType<typeof useVoiceConnectionStore>): Promise<void> {
    const room = voice.active
    queuedChange = queuedChange.catch(() => undefined).then(async () => {
      if (room && voice.active === room) await voice.setMicrophoneMuted(!(keyboardPressed || touchPressed))
    })
    return queuedChange
  }

  function release(voice: ReturnType<typeof useVoiceConnectionStore>): void {
    keyboardPressed = touchPressed = false
    pushToTalk?.reset()
    void queueMute(voice)
  }

  async function start(): Promise<void> {
    const voice = useVoiceConnectionStore()
    if (!voice.active) {
      if (!touchPttEnabled.value) error.value = 'Сначала подключитесь к голосовому каналу.'
      return
    }
    await stop(false)
    const room = voice.active
    if (!room) return
    mutedBeforePtt = voice.microphoneMuted
    room.pushToTalk = true
    await voice.setMicrophoneMuted(true)
    if (voice.active !== room) return
    if (!pttKey.value && !touchPttEnabled.value) {
      error.value = 'Для push-to-talk назначьте клавишу.'
      return
    }
    error.value = null
    sessionActive = true
    stopObserving = watch([() => voice.active, () => voice.state], ([current, state], [previous]) => {
      if (current === previous && !['RECONNECTING', 'LEAVING', 'ERROR', 'IDLE'].includes(state)) return
      if (current) current.pushToTalk = true
      release(voice)
    }, { flush: 'sync' })
    if (!pttKey.value) return
    pushToTalk = new PushToTalk(browserEvents(), pttKey.value, (pressed) => {
      keyboardPressed = pressed
      void queueMute(voice)
    })
    pushToTalk.start()
  }

  async function setTouchPressed(pressed: boolean): Promise<void> {
    if (!touchPttEnabled.value || !sessionActive || touchPressed === pressed) return
    const voice = useVoiceConnectionStore()
    const canPublish = voice.state === 'CONNECTED' || (voice.state === 'LISTENER' && voice.active?.listenerOnly === true)
    if (pressed && (!voice.active || !canPublish || voice.deafened || voice.microphonePermissionDenied)) return
    touchPressed = pressed
    await queueMute(voice)
  }

  async function stop(restoreMute = true): Promise<void> {
    const voice = useVoiceConnectionStore(), room = voice.active
    stopObserving(); stopObserving = () => {}
    pushToTalk?.stop(); pushToTalk = null
    sessionActive = keyboardPressed = touchPressed = false
    if (room) room.pushToTalk = false
    await queuedChange.catch(() => undefined)
    if (restoreMute && mutedBeforePtt !== null && voice.active === room) await voice.setMicrophoneMuted(mutedBeforePtt)
    mutedBeforePtt = null
  }

  return { start, stop, setTouchPressed }
}
