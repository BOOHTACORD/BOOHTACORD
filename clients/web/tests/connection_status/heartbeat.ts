import { createPinia, setActivePinia } from 'pinia'
import { useRealtimeStore } from '../../src/realtime/realtime_store'

setActivePinia(createPinia())
const store = useRealtimeStore()
Object.assign(window, { heartbeatFixture: {
  start: (url: string) => store.connect(() => {}, undefined, url, { checkSession: async () => true, random: () => 0 }),
  state: () => store.state,
  stop: () => store.disconnect(),
} })
