import { describe, expect, it, vi } from 'vitest'

import type { ScreenDiagnostics } from './screen_diagnostics'
import { buildWebScreenTelemetryEnvelope, postScreenTelemetryEnvelope } from './screen_sender_telemetry'

const scope = {
  ownerLeaseId: '11111111-1111-4111-8111-111111111111',
  mediaSessionId: 'media-session-1',
  publicationGeneration: 4,
  captureWidth: 1920,
  captureHeight: 1080,
  captureFps: 30,
}

describe('Web screen sender telemetry envelope', () => {
  it('maps the existing selected screen sender sample to bounded, provenance-aware values', () => {
    const diagnostics = {
      source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD',
      measured: { width: 1280, height: 720, framesPerSecond: 24 },
      sampledAt: 95_000, senderStatsAvailable: true,
      selectedLayer: { framesPerSecond: 24, bitrateBps: 1_400_000, packetLossPercent: 2, roundTripTimeMs: 40, qualityLimitationReason: 'cpu' },
      bitrateBps: 1_400_000, packetLossPercent: 2, packetLossWindowMs: 10_000,
      roundTripTimeMs: 40, adaptationReason: 'cpu',
    } as unknown as ScreenDiagnostics

    expect(buildWebScreenTelemetryEnvelope({ scope, diagnostics, sequence: 7, nowMs: 100_000 })).toEqual({
      schema_version: 1,
      media_session_id: 'media-session-1',
      publication_generation: 4,
      platform: 'web',
      client_kind: 'web',
      capability_version: 1,
      sequence: 7,
      sender_sample_age_ms: 5_000,
      capture: {
        width: { value: 1920, availability: 'measured', provenance: 'sender_measured' },
        height: { value: 1080, availability: 'measured', provenance: 'sender_measured' },
        fps: { value: 30, availability: 'configured_only', provenance: 'configured' },
      },
      encode: {
        fps: { value: 24, availability: 'measured', provenance: 'sender_measured' },
        bitrate_bps: { value: 1_400_000, availability: 'measured', provenance: 'sender_measured' },
      },
      transport: {
        packet_loss_percent: { value: 2, availability: 'measured', provenance: 'sender_measured' },
        rtt_ms: { value: 40, availability: 'measured', provenance: 'sender_measured' },
        quality_limitation_reason: { value: 'cpu', availability: 'measured', provenance: 'sender_measured' },
      },
    })
  })

  it('rounds the derived bitrate to the integer bps accepted by the relay contract', () => {
    const envelope = buildWebScreenTelemetryEnvelope({
      scope,
      diagnostics: {
        source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: null, senderStatsAvailable: true,
        selectedLayer: { bitrateBps: 1_400_000.6 },
      } as unknown as ScreenDiagnostics,
      sequence: 8,
      nowMs: 100_000,
    })!

    expect(envelope.encode.bitrate_bps).toEqual({ value: 1_400_001, availability: 'measured', provenance: 'sender_measured' })
  })

  it('marks unavailable or stale samples explicitly without inventing numbers', () => {
    const unavailable = buildWebScreenTelemetryEnvelope({
      scope: { ...scope, captureWidth: undefined, captureHeight: undefined, captureFps: undefined },
      diagnostics: { source: 'UNKNOWN', audioTrack: 'UNKNOWN', connectionQuality: 'UNKNOWN', measured: null, senderStatsAvailable: false } as ScreenDiagnostics,
      sequence: 8,
      nowMs: 20_000,
    })!
    expect(unavailable.capture).toEqual({
      width: { availability: 'not_exposed', provenance: 'unavailable' },
      height: { availability: 'not_exposed', provenance: 'unavailable' },
      fps: { availability: 'not_exposed', provenance: 'unavailable' },
    })
    expect(unavailable.encode.fps).toEqual({ availability: 'unsupported', provenance: 'unavailable' })
    expect(unavailable.transport.rtt_ms).toEqual({ availability: 'unsupported', provenance: 'unavailable' })

    const stale = buildWebScreenTelemetryEnvelope({
      scope,
      diagnostics: { source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD', measured: null, sampledAt: 1_000, senderStatsAvailable: true } as ScreenDiagnostics,
      sequence: 9,
      nowMs: 20_000,
    })!
    expect(stale.sender_sample_age_ms).toBe(19_000)
    expect(stale.encode.fps).toEqual({ availability: 'stale', provenance: 'unavailable' })
  })

  it('posts only the scoped envelope through the same-origin lease route', async () => {
    const envelope = buildWebScreenTelemetryEnvelope({
      scope, diagnostics: { source: 'UNKNOWN', audioTrack: 'UNKNOWN', connectionQuality: 'UNKNOWN', measured: null } as ScreenDiagnostics,
      sequence: 1, nowMs: 10_000,
    })!
    const request = vi.fn(async () => new Response(null, { status: 204 }))
    await postScreenTelemetryEnvelope(scope.ownerLeaseId, envelope, request)
    expect(request).toHaveBeenCalledWith('/api/v1/voice/leases/11111111-1111-4111-8111-111111111111/screen-telemetry', expect.objectContaining({
      method: 'POST', mode: 'same-origin', credentials: 'same-origin', cache: 'no-store', referrerPolicy: 'no-referrer',
      headers: { accept: 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify(envelope),
    }))
    expect(JSON.stringify(envelope)).not.toMatch(/track|ssrc|username|window_title|account_id/i)
  })
})
