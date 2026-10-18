import { afterEach, describe, expect, it, vi } from 'vitest'

import { bindLiveKitScreenViewerPresence, screenViewerHeartbeatMs } from './screen_viewer_presence'

const ownerLeaseID = '22222222-2222-4222-8222-222222222222'
const viewerLeaseID = '11111111-1111-4111-8111-111111111111'
const viewerAccountID = '33333333-3333-4333-8333-333333333333'
const events = {
  localTrackPublished: 'local-track-published',
  localTrackUnpublished: 'local-track-unpublished',
  participantDisconnected: 'participant-disconnected',
  trackSubscribed: 'track-subscribed',
  trackUnsubscribed: 'track-unsubscribed',
}

function response(body: unknown = {}): Response { return { ok: true, json: async () => body } as Response }

function fixture(accounts: string[] = [], mode: 'owner' | 'viewer' = 'owner') {
  const listeners = new Map<string, (...args: any[]) => void>()
  const localVideo = { source: 'screen-video', trackSid: 'owner-screen-track' }
  const localID = mode === 'owner' ? ownerLeaseID : viewerLeaseID
  const remoteID = mode === 'owner' ? viewerLeaseID : ownerLeaseID
  const local = { identity: `voice-lease:${localID}`, getTrackPublication: () => localVideo }
  const aliceVideo = { source: 'screen-video', trackSid: 'remote-screen-track' }
  const alice = {
    identity: `voice-lease:${remoteID}`, metadata: `account:${viewerAccountID}`, name: 'Алиса',
    getTrackPublication: (source: string) => source === 'screen-video' ? aliceVideo : undefined,
  }
  const room = {
    localParticipant: local,
    remoteParticipants: new Map([[alice.identity, alice]]),
    on: vi.fn((event: string, listener: (...args: any[]) => void) => listeners.set(event, listener)),
  }
  const request = vi.fn(async (_input: string, _init: RequestInit) => response({ viewer_account_ids: accounts }))
  const watchers = vi.fn()
  const presence = bindLiveKitScreenViewerPresence(room, events, 'screen-video', watchers, request, screenViewerHeartbeatMs)
  return { alice, aliceVideo, listeners, local, localVideo, presence, request, room, watchers }
}

describe('LiveKit screen viewer presence', () => {
  afterEach(() => vi.useRealTimers())

  it('reports the confirmed screen subscription and removes only that track through the authenticated API', async () => {
    const { alice, aliceVideo, listeners, presence, request } = fixture([], 'viewer')

    listeners.get('track-subscribed')!({}, aliceVideo, alice)
    listeners.get('track-unsubscribed')!({}, aliceVideo, alice)
    await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(2))

    expect(request.mock.calls[0]![0]).toBe(`/api/v1/voice/leases/${viewerLeaseID}/screen-viewers/${ownerLeaseID}`)
    expect(request.mock.calls[0]![1]).toMatchObject({
      method: 'PUT', mode: 'same-origin', credentials: 'same-origin', cache: 'no-store',
      body: JSON.stringify({ track_sid: 'remote-screen-track' }),
    })
    expect(request.mock.calls[1]![0]).toContain('?track_sid=remote-screen-track')
    expect(request.mock.calls[1]![1]).toMatchObject({ method: 'DELETE', credentials: 'same-origin', cache: 'no-store' })
    presence.clear()
  })

  it('loads a private owner snapshot and maps account IDs to current participant names', async () => {
    const { listeners, localVideo, presence, request, watchers } = fixture([viewerAccountID])
    listeners.get('local-track-published')!(localVideo)
    await vi.waitFor(() => expect(watchers).toHaveBeenCalledWith([{ id: viewerAccountID, accountId: viewerAccountID, name: 'Алиса' }]))
    expect(request.mock.calls[0]![0]).toBe(`/api/v1/voice/leases/${ownerLeaseID}/screen-viewers`)
    expect(request.mock.calls[0]![1]).toMatchObject({ method: 'GET', credentials: 'same-origin', cache: 'no-store' })
    presence.clear()
  })

  it('heartbeats active viewers and removes their presence when they disconnect', async () => {
    vi.useFakeTimers()
    const { alice, aliceVideo, listeners, presence, request } = fixture([], 'viewer')
    listeners.get('track-subscribed')!({}, aliceVideo, alice)
    expect(request).toHaveBeenCalledTimes(1)
    await vi.advanceTimersByTimeAsync(screenViewerHeartbeatMs)
    expect(request).toHaveBeenCalledTimes(2)

    listeners.get('participant-disconnected')!(alice)
    expect(request).toHaveBeenCalledTimes(3)
    expect(request.mock.calls[2]![0]).toContain('?track_sid=remote-screen-track')
    presence.clear()
  })

  it('does not let an old unsubscribe remove a replacement screen track', async () => {
    const { alice, aliceVideo, listeners, presence, request } = fixture([], 'viewer')
    listeners.get('track-subscribed')!({}, aliceVideo, alice)
    const replacement = { source: 'screen-video', trackSid: 'new-screen-track' }
    listeners.get('track-subscribed')!({}, replacement, alice)
    listeners.get('track-unsubscribed')!({}, aliceVideo, alice)
    await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(3))
    expect(request.mock.calls[2]![0]).toContain('?track_sid=remote-screen-track')
    presence.clear()
  })
})
