import { effectScope, ref } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { unknownScreenDiagnostics } from './screen_diagnostics'
import { installScreenSenderReporting } from './screen_sender_reporting'
import { telemetrySession } from '../telemetry/action_scope/session'
import type { ScreenShareState } from './screen_controls'

afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals() })

describe('screen sender reporting', () => {
  it('reports an active Android sender while its page is hidden and stops with the share', async () => {
    vi.useFakeTimers()
    vi.stubGlobal('document', { visibilityState: 'hidden' })
    const request = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      void input
      void init
      return new Response(null, { status: 204 })
    })
    vi.stubGlobal('fetch', request)
    const state = ref<ScreenShareState>('IDLE')
    const diagnostics = ref(unknownScreenDiagnostics())
    const refresh = vi.fn(async () => { diagnostics.value = {
      source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD',
      measured: { width: 1080, height: 2400, framesPerSecond: 18 },
    } })
    const scope = effectScope()
    scope.run(() => installScreenSenderReporting(state, diagnostics, refresh, 'android_web'))

    state.value = 'SHARING'
    await vi.advanceTimersByTimeAsync(1000)
    expect(refresh).toHaveBeenCalledTimes(2)
    await vi.advanceTimersByTimeAsync(4000)
    expect(refresh).toHaveBeenCalledTimes(6)
    expect(request).toHaveBeenCalledOnce()
    const [, init] = request.mock.calls[0] as unknown as [string, RequestInit]
    expect(JSON.parse(String(init.body))).toMatchObject({ direction: 'sender', platform: 'android_web', encoded_fps: 18 })

    state.value = 'IDLE'
    await vi.advanceTimersByTimeAsync(10000)
    expect(request).toHaveBeenCalledOnce()
    scope.stop()
  })

  it('uses the existing five-second sender report tick for the scoped relay', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-11-16T00:00:00Z'))
    const leaseId = '11111111-1111-4111-8111-111111111111'
    telemetrySession.endMedia()
    expect(telemetrySession.bindMediaLease(leaseId)).toBe(true)
    let finishRelay!: (response: Response) => void
    const pendingRelay = new Promise<Response>(resolve => { finishRelay = resolve })
    const request = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      void init
      if (String(input).endsWith('/screen-telemetry')) return pendingRelay
      return new Response(null, { status: 204 })
    })
    vi.stubGlobal('fetch', request)
    const state = ref<ScreenShareState>('IDLE')
    const diagnostics = ref(unknownScreenDiagnostics())
    const refresh = vi.fn(async () => { diagnostics.value = {
      source: 'ACTIVE', audioTrack: 'ABSENT', connectionQuality: 'GOOD',
      measured: { width: 1280, height: 720, framesPerSecond: 24 }, sampledAt: Date.now(),
      senderStatsAvailable: true,
      selectedLayer: { framesPerSecond: 24, bitrateBps: 1_400_000, packetLossPercent: 2, roundTripTimeMs: 40, qualityLimitationReason: 'cpu' } as never,
      packetLossPercent: 2, packetLossWindowMs: 10_000, roundTripTimeMs: 40,
    } })
    const scope = effectScope()
    scope.run(() => installScreenSenderReporting(state, diagnostics, refresh, 'desktop_web', () => null, () => ({
      ownerLeaseId: leaseId, mediaSessionId: 'media-session-1', publicationGeneration: 3,
      captureWidth: 1920, captureHeight: 1080, captureFps: 30,
    })))

    state.value = 'SHARING'
    await vi.advanceTimersByTimeAsync(5000)
    expect(refresh).toHaveBeenCalledTimes(6)
    expect(request).toHaveBeenCalledTimes(2)
    expect(request.mock.calls.map(call => String(call[0]))).toContain('/api/v1/voice/leases/11111111-1111-4111-8111-111111111111/screen-telemetry')
    const relay = request.mock.calls.find(call => String(call[0]).endsWith('/screen-telemetry'))
    expect(JSON.parse(String(relay?.[1]?.body))).toMatchObject({
      schema_version: 1, media_session_id: 'media-session-1', publication_generation: 3,
      platform: 'web', client_kind: 'web', sequence: 1,
      encode: { fps: { value: 24, availability: 'measured' } },
    })

    await vi.advanceTimersByTimeAsync(5000)
    expect(request).toHaveBeenCalledTimes(3)
    expect(request.mock.calls.filter(call => String(call[0]).endsWith('/screen-telemetry'))).toHaveLength(1)
    finishRelay(new Response(null, { status: 204 }))
    await Promise.resolve()
    await Promise.resolve()

    state.value = 'IDLE'
    await vi.advanceTimersByTimeAsync(10_000)
    expect(request).toHaveBeenCalledTimes(3)
    telemetrySession.endMedia()
    scope.stop()
  })
})
