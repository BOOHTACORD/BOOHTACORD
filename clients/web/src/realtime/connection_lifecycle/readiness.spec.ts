import { createPinia, setActivePinia } from 'pinia'
import { afterEach, expect, it, vi } from 'vitest'
import { useRealtimeStore, type RealtimeSocket } from '../realtime_store'

afterEach(() => vi.useRealTimers())
function start() {
  vi.useFakeTimers(); setActivePinia(createPinia())
  const sockets: RealtimeSocket[] = [], store = useRealtimeStore()
  store.connect(vi.fn(), () => {
    const socket: RealtimeSocket = {close:vi.fn(),onopen:null,onmessage:null,onerror:null,onclose:null}
    sockets.push(socket); return socket
  },'ws://owned.test/api/v1/realtime',{checkSession:async()=>true,random:()=>0})
  return {store,sockets}
}

it('keeps chat connecting after upgrade until actual server ready', () => {
  const {store,sockets}=start()
  try {
    sockets[0].onopen?.(new Event('open'))
    expect(store.state).toBe('CONNECTING')
    sockets[0].onmessage?.(new MessageEvent('message',{data:JSON.stringify({
      event_id:'11111111-1111-4111-8111-111111111111',kind:'connection.ready',
      occurred_at:'2026-11-21T00:00:00Z',payload:{}})}))
    expect(store.state).toBe('CONNECTED')
    expect(store.error).toBeNull()
  } finally { store.disconnect() }
})

it('late upgrade consumes the same fifteen second ready budget', async () => {
  const {store,sockets}=start()
  try {
    await vi.advanceTimersByTimeAsync(14000)
    sockets[0].onopen?.(new Event('open'))
    await vi.advanceTimersByTimeAsync(999)
    expect(store.state).toBe('CONNECTING')
    expect(sockets[0].close).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(1)
    expect(sockets[0].close).toHaveBeenCalledOnce()
    await vi.advanceTimersByTimeAsync(500)
    expect(sockets).toHaveLength(2)
    expect(store.state).toBe('CONNECTING')
  } finally { store.disconnect() }
})
