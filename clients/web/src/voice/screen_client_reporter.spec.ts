import { describe, expect, it, vi } from 'vitest'

import { buildScreenClientReport, buildSenderScreenReport, postScreenClientReport, webPlatform } from './screen_client_reporter'

describe('anonymous screen client reports', () => {
  it('classifies a selected stream before subscription and after the first frame', () => {
    const base = { selected: true, hasTrack: false, videoReady: false, playbackFps: null, receiverMetrics: null, platform: 'ios_web' as const }
    expect(buildScreenClientReport(base)).toMatchObject({ platform: 'ios_web', direction: 'receiver', state: 'waiting_subscription' })
    expect(buildScreenClientReport({ ...base, hasTrack: true })).toMatchObject({ state: 'waiting_first_frame' })
    expect(buildScreenClientReport({ ...base, hasTrack: true, videoReady: true, playbackFps: 0 })).toMatchObject({ state: 'stalled', presented_fps: 0 })
    expect(buildScreenClientReport({ ...base, hasTrack: true, videoReady: true, playbackFps: 26.5, receiverMetrics: { decodedFps: 29.7, bitrateKbps: 1100, packetsLost: 2, packetLossPercent: null, droppedFrames: 1, jitterMs: 4, rttMs: null } })).toMatchObject({
      platform: 'ios_web', direction: 'receiver', state: 'playing', presented_fps: 26.5, decoded_fps: 29.7, bitrate_kbps: 1100, packets_lost: 2, dropped_frames: 1, jitter_ms: 4,
    })
    expect(buildScreenClientReport({ ...base, hasTrack: true, videoReady: true, playbackFps: 26, receiverMetrics: null, frameWidth: 540, frameHeight: 1170 })).toMatchObject({ frame_width: 540, frame_height: 1170 })
    expect(buildScreenClientReport({ ...base, hasTrack: true, videoReady: true, playbackFps: 26, receiverMetrics: null, frameWidth: 9000, frameHeight: 1170 })).not.toHaveProperty('frame_width')
    expect(buildScreenClientReport({ ...base, selected: false })).toBeNull()
  })

  it('uses a fixed platform label and sends no account or stream identity', async () => {
    expect(webPlatform('Mozilla/5.0 (iPhone; CPU iPhone OS 26_0)')).toBe('ios_web')
    expect(webPlatform('Mozilla/5.0 (Linux; Android 16)')).toBe('android_web')
    expect(webPlatform('Mozilla/5.0 (Windows NT 10.0)')).toBe('desktop_web')
    const request = vi.fn(async () => new Response(null, { status: 204 }))
    await postScreenClientReport({ platform: 'ios_web', direction: 'receiver', state: 'waiting_first_frame' }, request)
    const [url, init] = request.mock.calls[0] as unknown as [string, RequestInit]
    expect(url).toBe('/api/v1/voice/screen-metrics')
    expect(init.credentials).toBe('same-origin')
    expect(init.body).toBe('{"platform":"ios_web","direction":"receiver","state":"waiting_first_frame"}')
  })

  it('includes the server-issued voice lease handle when reporting an active media session', async () => {
    const request = vi.fn(async () => new Response(null, { status: 204 }))
    const report = { platform: 'desktop_web' as const, direction: 'receiver' as const, state: 'playing' as const }
    await postScreenClientReport(report, request, '11111111-1111-4111-8111-111111111111')
    const [, init] = request.mock.calls[0] as unknown as [string, RequestInit]
    expect(JSON.parse(String(init.body))).toEqual({ ...report, voice_lease_id: '11111111-1111-4111-8111-111111111111' })
  })

  it('reports measured sender FPS without substituting the selected target', () => {
    expect(buildSenderScreenReport('desktop_web', { source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: { width: 1920, height: 1080, framesPerSecond: 27 }, bitrateBps: 1800000, roundTripTimeMs: 45 })).toMatchObject({
      platform: 'desktop_web', direction: 'sender', state: 'playing', connection_quality: 'GOOD', frame_width: 1920, frame_height: 1080, encoded_fps: 27, bitrate_kbps: 1800, rtt_ms: 45,
    })
    expect(buildSenderScreenReport('desktop_web', { source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: { width: 1920, height: 1080 } })).toMatchObject({
      platform: 'desktop_web', direction: 'sender', state: 'playing', connection_quality: 'GOOD', frame_width: 1920, frame_height: 1080,
    })
  })
})
