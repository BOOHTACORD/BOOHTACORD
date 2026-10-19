import { setMicrophoneVad } from './microphone_processing/runtime'
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { createShortcutSettings } from './shortcuts/state'

import { createPttActivation } from './activation/ptt'
import { useVoiceConnectionStore } from './connection_store'
import { type VoiceShortcutAction } from './voice_shortcut'
import { browserSupportsTouchPtt } from './touch_ptt'

export type VoiceActivationMode = 'VAD' | 'PTT'

export const useVoiceActivationStore = defineStore('voice-activation', () => {
  const error = ref<string | null>(null)
  const mode = ref<VoiceActivationMode>('VAD')
  const pttKey = ref<string | null>(null)
  const touchPttEnabled = ref(browserSupportsTouchPtt())
  const { start: startPtt, stop, setTouchPressed } = createPttActivation(pttKey, error, touchPttEnabled)
  const settings = createShortcutSettings(error, pttKey)
  const { microphoneShortcut, deafenShortcut, shortcutStatus, setShortcut, resetShortcuts, unbindAccount: clearShortcutAccount } = settings
  let boundAccount: string | null = null
  function bindAccount(id: string): void { if (id !== boundAccount) { pttKey.value = null; mode.value = 'VAD'; boundAccount = id }; settings.bindAccount(id) }
  function unbindAccount(): void { clearShortcutAccount(); boundAccount = null; pttKey.value = null; mode.value = 'VAD'; void stop(false).catch(() => undefined) }
  async function setMode(nextMode: VoiceActivationMode): Promise<void> {
    mode.value = nextMode
    error.value = null
    if (nextMode === 'VAD') {
      setMicrophoneVad(true)
      await stop()
      return
    }
    await startPtt()
    setMicrophoneVad(false)
  }

  async function setPttKey(key: string): Promise<void> {
    if (microphoneShortcut.value?.code === key || deafenShortcut.value?.code === key) {
      error.value = 'Эта клавиша уже назначена для другого действия.'
      return
    }
    pttKey.value = key
    error.value = null
    if (mode.value === 'PTT') await startPtt()
  }

  function announceShortcut(action: VoiceShortcutAction, result?: 'applied' | 'blocked'): void {
    const voice = useVoiceConnectionStore()
    if (!voice.active) {
      shortcutStatus.value = action === 'microphone' ? 'Микрофон недоступен: подключитесь к голосовому каналу.' : 'Звук недоступен: подключитесь к голосовому каналу.'
      return
    }
    if (result === 'blocked') { shortcutStatus.value = action === 'microphone' ? 'Микрофон не изменён.' : 'Звук не изменён.'; return }
    shortcutStatus.value = action === 'microphone'
      ? voice.deafened || voice.microphonePermissionDenied || mode.value === 'PTT' || voice.state === 'LISTENER' || voice.active.listenerOnly
        ? 'Микрофон остаётся выключенным.'
        : voice.microphoneMuted ? 'Микрофон выключен.' : 'Микрофон включён.'
      : voice.deafened ? 'Звук выключен.' : 'Звук включён.'
  }

  return { error, mode, pttKey, touchPttEnabled, microphoneShortcut, deafenShortcut, shortcutStatus, bindAccount, unbindAccount, resetShortcuts, setMode, setPttKey, setShortcut, setTouchPttPressed: setTouchPressed, announceShortcut, stop }
})
