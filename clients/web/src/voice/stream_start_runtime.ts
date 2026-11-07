import { ref } from 'vue'

import type { ScreenViewerCard } from './screen_viewer_types'
import { StreamStartAlert, type StreamAlertPhase } from './stream_start_alert'
import { StreamStartChime } from './stream_start_chime'

export const streamStartChime = new StreamStartChime()
// Superseded by account-scoped publisher/room events. Keep visual notices.
streamStartChime.play = () => {}
streamStartChime.playVoiceEvent = () => {}
export const streamStartNotice = ref(false)
let noticeTimer: ReturnType<typeof setTimeout> | null = null

const alert = new StreamStartAlert(() => {
  streamStartNotice.value = true
  if (noticeTimer) clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => { streamStartNotice.value = false; noticeTimer = null }, 6000)
  streamStartChime.play()
})

export function observeStreamStarts(cards: ScreenViewerCard[], phase: StreamAlertPhase): void {
  alert.observe(cards, phase)
  if (phase === 'CONNECTED' || phase === 'LISTENER' || phase === 'RECONNECTING') return
  if (noticeTimer) clearTimeout(noticeTimer)
  noticeTimer = null
  streamStartNotice.value = false
}
