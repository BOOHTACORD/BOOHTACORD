import { describe, expect, it, vi } from 'vitest'

import { loadVoiceRosters, parseVoiceRosters } from './voice_roster_client'

describe('voice rosters for an authenticated non-participant', () => {
  it('accepts empty rooms and names connected members without a local voice lease', async () => {
    const body = { channels: [
      { channel_id: 'voice-1', participants: [{ account_id: 'user-1', display_name: 'Мика', screen_sharing: true, microphone_muted: false }] },
      { channel_id: 'voice-2', participants: [] },
    ] }
    const request = vi.fn().mockResolvedValue(new Response(JSON.stringify(body), { status: 200 }))

    expect(await loadVoiceRosters(request)).toEqual([
      { channelId: 'voice-1', participants: [{ accountId: 'user-1', displayName: 'Мика', screenSharing: true, microphoneMuted: false, deafened: false }] },
      { channelId: 'voice-2', participants: [] },
    ])
    expect(request).toHaveBeenCalledWith('/api/v2/voice/participants', expect.objectContaining({ credentials: 'same-origin' }))
  })

  it('does not present an unavailable snapshot as an empty room', async () => {
    const request = vi.fn().mockResolvedValue(new Response(null, { status: 503 }))
    await expect(loadVoiceRosters(request)).rejects.toThrow('503')
  })

  it('rejects malformed identity and duplicate channel data', () => {
    expect(() => parseVoiceRosters({ channels: [{ channel_id: 'voice-1', participants: [{ account_id: '', display_name: 'Мика', screen_sharing: false }] }] })).toThrow()
    expect(() => parseVoiceRosters({ channels: [{ channel_id: 'voice-1', participants: [{ account_id: 'user-1', display_name: 'Мика', screen_sharing: false }] }] })).toThrow()
    expect(() => parseVoiceRosters({ channels: [{ channel_id: 'voice-1', participants: [] }, { channel_id: 'voice-1', participants: [] }] })).toThrow()
  })

  it('parses the strict v2 replicated deafen state', () => {
    expect(parseVoiceRosters({ channels: [{ channel_id: 'voice-1', participants: [{ account_id: 'user-1', display_name: 'Мика', screen_sharing: false, microphone_muted: true, deafened: true }] }] })).toEqual([
      { channelId: 'voice-1', participants: [{ accountId: 'user-1', displayName: 'Мика', screenSharing: false, microphoneMuted: true, deafened: true }] },
    ])
    expect(() => parseVoiceRosters({ channels: [{ channel_id: 'voice-1', participants: [{ account_id: 'user-1', display_name: 'Мика', screen_sharing: false, microphone_muted: true, deafened: 'true' }] }] })).toThrow()
  })
})
