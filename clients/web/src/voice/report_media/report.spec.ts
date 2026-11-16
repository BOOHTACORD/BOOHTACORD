import { describe, expect, it } from 'vitest'
import { buildScreenClientReport, buildSenderScreenReport } from '../screen_client_reporter'

describe('media telemetry measurements', () => {
  it('separates selected sender profile from actual quality and preserves zero loss', () => {
    const report = buildSenderScreenReport('desktop_web', {
      source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD',
      measured: { width: 1280, height: 720, framesPerSecond: 42 }, bitrateBps: 3500000,
      roundTripTimeMs: 32, packetLossPercent: 0, packetLossWindowMs: 10000, adaptationReason: 'bandwidth',
    }, 'P1440_60')
    expect(report).toMatchObject({ target_resolution: 1440, target_fps: 60, frame_width: 1280,
      encoded_fps: 42, bitrate_kbps: 3500, rtt_ms: 32, packet_loss_percent: 0,
      packet_loss_window_ms: 10000, connection_quality: 'GOOD', adaptation_reason: 'bandwidth' })
  })
  it('reports receiver loss and does not repeat a stale sample', () => {
    const input = { platform: 'desktop_web' as const, selected: true, hasTrack: true, videoReady: true,
      playbackFps: 29, sampledAt: Date.now(), packetLossWindowMs: 10000,
      receiverMetrics: { decodedFps: 30, bitrateKbps: 6000, jitterMs: 2, packetsLost: 999,
        droppedFrames: 0, packetLossPercent: 1.5, rttMs: null } }
    expect(buildScreenClientReport(input)).toMatchObject({ packet_loss_percent: 1.5, packet_loss_window_ms: 10000 })
    expect(buildScreenClientReport({ ...input, sampledAt: Date.now() - 16000 })).toBeNull()
  })
})
