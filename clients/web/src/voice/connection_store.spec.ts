import { createPinia, setActivePinia } from 'pinia'
import { isProxy } from 'vue'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { buildVoiceNavigationPresence } from '../channel/voice_navigation_presence'
import { useAuthorDirectory } from '../identity/author_directory'

const fixture = vi.hoisted(() => {
  const room: Record<string, unknown> = {}
  room.self = room
  return {
    join: vi.fn(),
    leave: vi.fn(),
    participantSource: { cards: vi.fn(() => [] as Array<{ accountId: string; id: string; microphoneMuted: boolean; name?: string; speaking: boolean }>), onChange: vi.fn(() => () => undefined) },
    room,
    screenSource: { cards: vi.fn(() => [] as Array<{ accountId: string; hasAudio: boolean; id: string; participantId: string; participantName: string }>), watchers: vi.fn(() => []), onChange: vi.fn(() => () => undefined), selectedId: null, selectedAccountId: null, ended: false, setAudioVolume: vi.fn() },
  }
})

vi.mock('../identity/current_session', () => ({
  loadCurrentSession: vi.fn().mockResolvedValue({ accountId: 'account-1' }),
}))

vi.mock('./voice_session', () => ({
  VoiceSession: class {
    audioProcessing = { diagnostics: { supported: false } }
    screen = {}
    join = fixture.join
    leave = fixture.leave
    get active() { return null }
    participantCards = () => fixture.participantSource
    remoteVoices = () => null
    screenViewer = () => fixture.screenSource
    setAudioProcessing = vi.fn().mockResolvedValue(undefined)
    setConnectionObserver = vi.fn()
  },
}))

import { useVoiceConnectionStore } from './connection_store'

describe('voice connection store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    fixture.join.mockReset()
    fixture.leave.mockReset()
    fixture.participantSource.cards.mockReturnValue([])
    fixture.screenSource.cards.mockReturnValue([])
    fixture.join.mockResolvedValue({
      channelId: 'channel-1',
      leaseId: 'lease-1',
      microphone: 'PUBLISHED',
      room: fixture.room,
      screenProfile: null,
    })
  })

  it('does not make the cyclic LiveKit room reactive after joining', async () => {
    const store = useVoiceConnectionStore()

    await store.join('channel-1')

    expect(store.active?.room).toBe(fixture.room)
    expect(isProxy(store.active?.room)).toBe(false)
    expect(fixture.join).toHaveBeenCalledWith('channel-1', false, 'with-microphone')
  })

  it('keeps a listener-only join muted in the connected store', async () => {
    fixture.join.mockResolvedValueOnce({ channelId: 'channel-1', leaseId: 'lease-1', microphone: 'MUTED', room: fixture.room, screenProfile: null })
    const store = useVoiceConnectionStore()

    await store.join('channel-1', false, 'listener')

    expect(fixture.join).toHaveBeenCalledWith('channel-1', false, 'listener')
    expect(store.state).toBe('LISTENER')
    expect(store.microphoneMuted).toBe(true)
  })

  it('clears local active media state when release fails after the room disconnected', async () => {
    const store = useVoiceConnectionStore()
    await store.join('channel-1')
    fixture.leave.mockRejectedValueOnce(new Error('release failed'))

    await store.leave()

    expect(store.active).toBeNull()
    expect(store.state).toBe('IDLE')
  })

  it('updates voice cards and screen publisher names from the authenticated member profile', async () => {
    const accountId = '11111111-1111-4111-8111-111111111111'
    fixture.participantSource.cards.mockReturnValue([{ accountId, id: accountId, microphoneMuted: false, name: undefined, speaking: false }])
    fixture.screenSource.cards.mockReturnValue([{ accountId, hasAudio: false, id: `${accountId}:screen`, participantId: accountId, participantName: accountId }])
    const response = (name: string) => new Response(JSON.stringify({ user_id: accountId, login: 'member', display_name: name, role: 'MEMBER' }))
    let resolveProfile!:(value:Response)=>void
    const request = vi.spyOn(globalThis, 'fetch').mockImplementationOnce(()=>new Promise<Response>(resolve=>{resolveProfile=resolve})).mockResolvedValueOnce(response('Ник после переименования'))
    try {
      const store = useVoiceConnectionStore()
      await store.join('channel-1')
      expect(store.voiceVolumeParticipants[0]?.name).toBeUndefined()
      resolveProfile(response('Новый ник'))
      await vi.waitFor(() => expect(store.voiceVolumeParticipants[0]?.name).toBe('Новый ник'))
      expect(store.screenViewerCards[0]?.participantName).toBe('Новый ник')
      expect(buildVoiceNavigationPresence('channel-1', null, store)?.members[0]?.name).toBe('Новый ник')
      expect(request).toHaveBeenCalledTimes(1)
      expect(String(request.mock.calls[0]?.[0])).toContain(`/members/${accountId}`)
      await useAuthorDirectory().refreshKnown()
      expect(store.voiceVolumeParticipants[0]?.name).toBe('Ник после переименования')
      expect(store.screenViewerCards[0]?.participantName).toBe('Ник после переименования')
      expect(buildVoiceNavigationPresence('channel-1', null, store)?.members[0]?.name).toBe('Ник после переименования')
    } finally {
      request.mockRestore()
    }
  })
})
