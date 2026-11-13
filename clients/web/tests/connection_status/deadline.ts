import { createPinia, setActivePinia } from 'pinia'
import { useRealtimeStore } from '../../src/realtime/realtime_store'

setActivePinia(createPinia())
const store = useRealtimeStore()
let attempts = 0
Object.assign(window, { deadlineFixture: {
  start: (url: string) => store.connect(() => {}, target => {
    attempts++
    return new WebSocket(target)
  }, url, { checkSession: async () => true, random: () => 0 }),
  attempts: () => attempts,
  stop: () => store.disconnect(),
} })
