import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, expect, it, vi } from 'vitest'
import type { VoiceConnectionObserver } from '../voice_session_types'
const fixture = vi.hoisted(() => ({ active: null as any, observer: null as VoiceConnectionObserver | null, join: vi.fn(), leave: vi.fn(), revoke: vi.fn() }))
vi.mock('../voice_session', () => ({ VoiceSession: class {
  audioProcessing = { diagnostics: { supported: false } }; screen = {}
  get active() { return fixture.active }
  async join() { fixture.observer?.admitted?.('lease', 'channel'); fixture.active = await fixture.join(); return fixture.active }
  async leave() { await fixture.leave(); fixture.active = null }
  async revoke(id: string) { const done = await fixture.revoke(id); if (done) fixture.active = null; return done }
  participantCards = () => null; remoteVoices = () => null; screenViewer = () => null
  setAudioProcessing = vi.fn(async () => {}); setConnectionObserver = (observer: VoiceConnectionObserver) => { fixture.observer = observer }
} }))
import { useVoiceConnectionStore } from '../connection_store'
beforeEach(() => {
  setActivePinia(createPinia()); fixture.active = null
  fixture.join.mockReset().mockResolvedValue({ channelId: 'channel', leaseId: 'lease', microphone: 'MUTED', room: {}, screenProfile: null })
  fixture.leave.mockReset().mockResolvedValue(undefined); fixture.revoke.mockReset().mockResolvedValue(true)
})
it.each(['server-first', 'transport-first'])('preserves KICK in store for %s', async order => {
  const store = useVoiceConnectionStore(); await store.join('channel')
  if (order === 'server-first') { await store.revokeLease('lease', 'KICK'); fixture.observer?.disconnected() }
  else { fixture.active = null; fixture.observer?.disconnected(); await store.revokeLease('lease', 'KICK') }
  expect(store.error).toBe('Администратор отключил вас от голосового канала.')
  expect(store.disconnectNotice?.source).toBe('server'); expect(store.canJoin).toBe(true)
  await store.revokeLease('lease', 'KICK'); expect(fixture.revoke.mock.calls.length).toBe(order === 'server-first' ? 1 : 0)
  await store.join('channel'); expect(store.disconnectNotice).toBeNull()
  store.$dispose()
})
it('pending join keeps exact lease revocation and ignores duplicate delivery', async () => {
  let finish!: (value: any) => void
  fixture.join.mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
  const store = useVoiceConnectionStore(); const joining = store.join('channel')
  await store.revokeLease('foreign', 'BANNED'); await store.revokeLease('lease', 'KICK'); await store.revokeLease('lease', 'KICK')
  finish({ channelId: 'channel', leaseId: 'lease', microphone: 'MUTED', room: {}, screenProfile: null }); await joining
  expect(store.disconnectNotice?.reason).toBe('KICK'); expect(store.active).toBeNull()
  expect(fixture.revoke).toHaveBeenCalledTimes(1); store.$dispose()
})
it('KICK arriving during successful leave wins over local/transport outcome', async () => {
  let finish!: () => void
  fixture.leave.mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve }))
  const store = useVoiceConnectionStore(); await store.join('channel'); const leaving = store.leave()
  await store.revokeLease('lease', 'KICK'); fixture.observer?.disconnected(); finish(); await leaving
  expect(store.disconnectNotice?.reason).toBe('KICK'); expect(store.error).toContain('Администратор')
  expect(store.state).toBe('ERROR'); store.$dispose()
})

it('channel selection during teardown clears notice and still cleans the old session', async () => {
  let finish!: (value: boolean) => void
  fixture.revoke.mockImplementationOnce(() => new Promise(resolve => { finish = resolve }))
  const store = useVoiceConnectionStore(); await store.join('channel')
  const closing = store.revokeLease('lease', 'KICK'); store.selectDisconnectChannel('other'); finish(true); await closing
  expect(store.active).toBeNull(); expect(store.disconnectNotice).toBeNull(); expect(store.error).toBeNull()
  store.$dispose()
})

it('does not cancel recovery for its own voluntary release', async () => {
  const store = useVoiceConnectionStore(); await store.join('channel')
  fixture.active = null; fixture.observer?.disconnected(3)
  expect(store.state).toBe('RECONNECTING')
  expect(await store.revokeLease('lease', 'VOLUNTARY_LEAVE')).toBe(false)
  expect(store.state).toBe('RECONNECTING')
  expect(store.disconnectNotice).toBeNull()
  store.$dispose()
})
