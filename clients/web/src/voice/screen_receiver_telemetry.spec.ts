import { describe, expect, it } from 'vitest'

import { SelectedScreenTelemetry, parseScreenTelemetryEvent } from './screen_receiver_telemetry'
import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'
import type { ScreenShareDescriptorV1 } from './screen_profile_metadata/types'

const ownerLeaseId = '11111111-1111-4111-8111-111111111111'
const envelope = {
  schema_version: 1,
  media_session_id: 'session-a',
  publication_generation: 4,
  platform: 'web',
  client_kind: 'web',
  capability_version: 1,
  sequence: 2,
  sender_sample_age_ms: 120,
  capture: {
    width: { value: 1920, availability: 'measured', provenance: 'sender_measured' },
    height: { value: 1080, availability: 'measured', provenance: 'sender_measured' },
    fps: { value: 30, availability: 'measured', provenance: 'sender_measured' },
  },
  encode: {
    fps: { value: 30, availability: 'measured', provenance: 'sender_measured' },
    bitrate_bps: { value: 2_000_000, availability: 'measured', provenance: 'sender_measured' },
  },
  transport: {
    packet_loss_percent: { availability: 'not_exposed', provenance: 'unavailable' },
    rtt_ms: { value: 30, availability: 'measured', provenance: 'sender_measured' },
    quality_limitation_reason: { value: 'none', availability: 'measured', provenance: 'sender_measured' },
  },
}

function event(overrides: Record<string, unknown> = {}) {
  return { owner_lease_id: ownerLeaseId, server_received_at: '2026-11-16T10:00:00.000Z', envelope, ...overrides }
}

describe('selected screen sender telemetry', () => {
  it('parses the bounded versioned event and retains server receipt time', () => {
    expect(parseScreenTelemetryEvent(event())).toMatchObject({ ownerLeaseId, serverReceivedAt: '2026-11-16T10:00:00.000Z', envelope })
  })

  it('rejects malformed, oversized, unbounded and unknown telemetry payloads', () => {
    expect(() => parseScreenTelemetryEvent({ ...event(), unexpected: 'value' })).toThrow()
    expect(() => parseScreenTelemetryEvent(event({ owner_lease_id: 'not-a-uuid' }))).toThrow()
    expect(() => parseScreenTelemetryEvent(event({ server_received_at: 'yesterday' }))).toThrow()
    expect(() => parseScreenTelemetryEvent(event({ envelope: { ...envelope, sequence: 0 } }))).toThrow()
    expect(() => parseScreenTelemetryEvent(event({ envelope: { ...envelope, capture: { ...envelope.capture, fps: { value: 241, availability: 'measured', provenance: 'sender_measured' } } } }))).toThrow()
    expect(() => parseScreenTelemetryEvent(event({
      envelope: {
        ...envelope,
        transport: {
          ...envelope.transport,
          packet_loss_percent: { value: 1, availability: 'unsupported', provenance: 'unavailable' },
        },
      },
    }))).toThrow()
    expect(() => parseScreenTelemetryEvent({ ...event(), envelope: { ...envelope, noise: 'x'.repeat(4096) } })).toThrow()
  })

  it('accepts only fresh matching publication generations and increasing sequence/receipt time', () => {
    const state = new SelectedScreenTelemetry()
    const selectedAt = Date.parse('2026-11-16T10:00:00.000Z')
    state.setSelection({ streamId: 'remote:screen', ownerLeaseId, mediaSessionId: 'session-a', publicationGeneration: 4 })

    expect(state.accept(event(), selectedAt + 500)).toBe(true)
    expect(state.current(selectedAt + 500)?.envelope.sequence).toBe(2)
    expect(state.accept(event({ server_received_at: '2026-11-16T10:00:00.100Z', envelope: { ...envelope, sequence: 2 } }), selectedAt + 600)).toBe(false)
    expect(state.accept(event({ owner_lease_id: '22222222-2222-4222-8222-222222222222', server_received_at: '2026-11-16T10:00:00.200Z', envelope: { ...envelope, sequence: 3 } }), selectedAt + 700)).toBe(false)
    expect(state.accept(event({ server_received_at: '2026-11-16T10:00:00.200Z', envelope: { ...envelope, publication_generation: 5, sequence: 3 } }), selectedAt + 700)).toBe(false)
    expect(state.accept(event({ server_received_at: '2026-11-16T09:59:59.900Z', envelope: { ...envelope, sequence: 3 } }), selectedAt + 700)).toBe(false)
    expect(state.accept(event({ server_received_at: '2026-11-16T10:00:00.300Z', envelope: { ...envelope, sequence: 3 } }), selectedAt + 800)).toBe(true)
    expect(state.accept(event({ server_received_at: '2026-11-16T10:00:00.400Z', envelope: { ...envelope, sequence: 4, sender_sample_age_ms: 16_000 } }), selectedAt + 900)).toBe(false)
    expect(state.current(selectedAt + 16_000)).toBeUndefined()
  })

  it('clears retained telemetry when selection or connection scope changes', () => {
    const state = new SelectedScreenTelemetry()
    const received = Date.parse('2026-11-16T10:00:00.000Z')
    const selection = { streamId: 'remote:screen', ownerLeaseId, mediaSessionId: 'session-a', publicationGeneration: 4 }
    state.setSelection(selection)
    expect(state.accept(event(), received)).toBe(true)
    state.setSelection({ ...selection, streamId: 'other:screen', ownerLeaseId: '22222222-2222-4222-8222-222222222222' })
    expect(state.current(received)).toBeUndefined()
    expect(state.accept(event({ server_received_at: '2026-11-16T10:00:00.100Z', envelope: { ...envelope, sequence: 3 } }), received + 100)).toBe(false)
    state.setSelection(selection)
    expect(state.accept(event({ server_received_at: '2026-11-16T10:00:00.100Z' }), received + 100)).toBe(false)
    state.setSelection(null)
    expect(state.current(received)).toBeUndefined()
  })

  it('binds telemetry to the selected sharing descriptor and drops it on switch or unpublish', () => {
    const stream = (id: string, lease: string): ScreenViewerStream => ({
      hasAudio: false, id, ownerLeaseId: lease, participantId: id, participantName: id,
      descriptor: { publisher_state: 'sharing', scope: { media_session_id: 'session-a', publication_generation: 4 } } as ScreenShareDescriptorV1,
      video: { track: { attach: (element: HTMLMediaElement) => element, detach: () => [] } },
    })
    const first = stream('remote-one:screen', ownerLeaseId)
    const secondOwner = '22222222-2222-4222-8222-222222222222'
    const second = stream('remote-two:screen', secondOwner)
    let streams: ScreenViewerStream[] = [first, second]
    const controller = new ScreenViewerController(() => streams)
    const video = {} as HTMLVideoElement
    const receivedAt = Date.now()
    controller.select(first.id, video, null)
    expect(controller.acceptSenderTelemetry(event({ server_received_at: new Date(receivedAt).toISOString() }))).toBe(true)
    expect(controller.cards().find(card => card.id === first.id)?.senderTelemetry?.envelope.sequence).toBe(2)

    controller.select(second.id, video, null)
    expect(controller.cards().every(card => card.senderTelemetry === undefined)).toBe(true)
    expect(controller.acceptSenderTelemetry(event({ server_received_at: new Date(receivedAt + 1).toISOString() }))).toBe(false)

    controller.select(first.id, video, null)
    expect(controller.acceptSenderTelemetry(event({ server_received_at: new Date(receivedAt + 2).toISOString() }))).toBe(false)
    streams = [second]
    controller.reconcile()
    expect(controller.selectedId).toBeNull()
    expect(controller.cards().every(card => card.senderTelemetry === undefined)).toBe(true)
    controller.stop()
  })
})
