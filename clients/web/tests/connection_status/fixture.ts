import { createApp, h, reactive } from 'vue'
import ConnectionStatus from '../../src/workspace/connection_status/Status.vue'
import type { RealtimeState } from '../../src/realtime/realtime_store'
import type { VoiceConnectionState } from '../../src/voice/connection_store'
import '../../src/style.css'

const state = reactive({
  chat: 'DISCONNECTED' as RealtimeState,
  voice: 'DISCONNECTED' as VoiceConnectionState,
  rosterAvailable: false,
  lastUpdatedAt: Date.now() - 69_000,
  rosterRetained: false,
})
const events: string[] = []
Object.assign(window, {
  __connectionStatusFixture: {
    patch: (patch: Partial<typeof state>) => Object.assign(state, patch),
    events,
  },
})

createApp({
  render: () => h('main', { class: 'sidebar', style: 'width:100%;min-height:100vh;padding:0 8px' }, [
    h(ConnectionStatus, {
      chat: state.chat,
      voice: state.voice,
      rosterAvailable: state.rosterAvailable,
      lastUpdatedAt: state.lastUpdatedAt,
      rosterRetained: state.rosterRetained,
      onRetryChat: () => events.push('chat'),
      onRetryRoster: () => events.push('roster'),
    }),
  ]),
}).mount('#app')
