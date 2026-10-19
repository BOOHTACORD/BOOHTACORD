import type { Ref } from 'vue'
import { PushToTalk, type EventSource } from '../push_to_talk'
import { useVoiceConnectionStore } from '../connection_store'

let pushToTalk: PushToTalk | null = null
let mutedBeforePtt: boolean | null = null
let queuedChange: Promise<void> = Promise.resolve()

function browserEvents(): EventSource {
  return {
    addEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).addEventListener(type, listener as unknown as EventListener),
    removeEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).removeEventListener(type, listener as unknown as EventListener),
  }
}

export function createPttActivation(pttKey: Ref<string | null>, error: Ref<string | null>, touchPttEnabled: Ref<boolean>) {
  let keyboardPressed = false
  let touchPressed = false
  let sessionActive = false

  function queueMute(voice: ReturnType<typeof useVoiceConnectionStore>): Promise<void> {
    queuedChange = queuedChange.catch(() => undefined).then(() => voice.setMicrophoneMuted(!(keyboardPressed || touchPressed)))
    return queuedChange
  }

  async function start(): Promise<void> {
    const voice = useVoiceConnectionStore()
    if (!voice.active) {
      if (!touchPttEnabled.value) error.value = 'Сначала подключитесь к голосовому каналу.'
      return
    }

    await stop(false)
    mutedBeforePtt = voice.microphoneMuted
    await voice.setMicrophoneMuted(true)
    if (!pttKey.value && !touchPttEnabled.value) {
      error.value = 'Для push-to-talk назначьте клавишу.'
      return
    }

    error.value = null
    sessionActive = true
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
    pushToTalk?.stop()
    pushToTalk = null
    sessionActive = false
    keyboardPressed = false
    touchPressed = false
    await queuedChange.catch(() => undefined)
    if (restoreMute && mutedBeforePtt !== null) {
      await useVoiceConnectionStore().setMicrophoneMuted(mutedBeforePtt)
    }
    mutedBeforePtt = null
  }

  return { start, stop, setTouchPressed }
}
