export type ScreenTelemetryAvailability = 'measured' | 'configured_only' | 'unsupported' | 'not_exposed' | 'permission_denied' | 'not_applicable' | 'stale'
export type ScreenTelemetryProvenance = 'sender_measured' | 'configured' | 'unavailable'

export interface ScreenTelemetryMetricV1 {
  value?: number
  availability: ScreenTelemetryAvailability
  provenance: ScreenTelemetryProvenance
}

export interface ScreenTelemetryCategoricalMetricV1 {
  value?: string
  availability: ScreenTelemetryAvailability
  provenance: ScreenTelemetryProvenance
}

export interface ScreenTelemetryEnvelopeV1 {
  schema_version: 1
  media_session_id: string
  publication_generation: number
  platform: 'web' | 'android' | 'ios' | 'macos' | 'windows'
  client_kind: 'web' | 'flutter'
  capability_version: number
  sequence: number
  sender_sample_age_ms?: number
  capture: { width: ScreenTelemetryMetricV1; height: ScreenTelemetryMetricV1; fps: ScreenTelemetryMetricV1 }
  encode: { fps: ScreenTelemetryMetricV1; bitrate_bps: ScreenTelemetryMetricV1 }
  transport: {
    packet_loss_percent: ScreenTelemetryMetricV1
    rtt_ms: ScreenTelemetryMetricV1
    quality_limitation_reason: ScreenTelemetryCategoricalMetricV1
  }
}

export interface ScreenTelemetryEventV1 {
  ownerLeaseId: string
  serverReceivedAt: string
  envelope: ScreenTelemetryEnvelopeV1
}

export interface ScreenTelemetryPublicationSelection {
  streamId: string
  ownerLeaseId: string
  mediaSessionId: string
  publicationGeneration: number
}

export interface ReceivedScreenTelemetry extends ScreenTelemetryEventV1 {
  serverReceivedAtMs: number
  receivedAtMonotonicMs: number
}

export const screenTelemetryFreshnessMs = 15_000

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const sessionPattern = /^[A-Za-z0-9_-]{1,256}$/
const dateTimePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/
const availabilityValues = ['measured', 'configured_only', 'unsupported', 'not_exposed', 'permission_denied', 'not_applicable', 'stale'] as const
const unavailableValues = ['unsupported', 'not_exposed', 'permission_denied', 'not_applicable', 'stale'] as const
const provenanceValues = ['sender_measured', 'configured', 'unavailable'] as const
const maxSafeSequence = Number.MAX_SAFE_INTEGER
const maxEnvelopeBytes = 2_048

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}

function exactKeys(value: Record<string, unknown>, required: string[], optional: string[] = []): boolean {
  const allowed = new Set([...required, ...optional])
  return required.every(key => Object.hasOwn(value, key)) && Object.keys(value).every(key => allowed.has(key))
}

function integerInRange(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= min && value <= max
}

function numericMetric(value: unknown, minimum: number, maximum: number, integral = false): ScreenTelemetryMetricV1 | null {
  const source = record(value)
  if (!source || !exactKeys(source, ['availability', 'provenance'], ['value'])) return null
  const availability = source.availability
  const provenance = source.provenance
  if (!availabilityValues.includes(availability as typeof availabilityValues[number]) || !provenanceValues.includes(provenance as typeof provenanceValues[number])) return null
  if (source.value === undefined) {
    if (!unavailableValues.includes(availability as typeof unavailableValues[number]) || provenance !== 'unavailable') return null
    return { availability: availability as ScreenTelemetryAvailability, provenance: 'unavailable' }
  }
  if (typeof source.value !== 'number' || !Number.isFinite(source.value) || source.value < minimum || source.value > maximum || (integral && !Number.isInteger(source.value))) return null
  if (availability === 'measured' && provenance === 'sender_measured') return { value: source.value, availability, provenance }
  if (availability === 'configured_only' && provenance === 'configured') return { value: source.value, availability, provenance }
  return null
}

function categoricalMetric(value: unknown): ScreenTelemetryCategoricalMetricV1 | null {
  const source = record(value)
  if (!source || !exactKeys(source, ['availability', 'provenance'], ['value'])) return null
  const availability = source.availability
  const provenance = source.provenance
  if (!availabilityValues.includes(availability as typeof availabilityValues[number]) || !provenanceValues.includes(provenance as typeof provenanceValues[number])) return null
  if (source.value === undefined) {
    if (!unavailableValues.includes(availability as typeof unavailableValues[number]) || provenance !== 'unavailable') return null
    return { availability: availability as ScreenTelemetryAvailability, provenance: 'unavailable' }
  }
  if (availability !== 'measured' || provenance !== 'sender_measured' || typeof source.value !== 'string' || !['none', 'bandwidth', 'cpu', 'encoder'].includes(source.value)) return null
  return { value: source.value, availability, provenance }
}

function parseEnvelope(value: unknown): ScreenTelemetryEnvelopeV1 | null {
  const source = record(value)
  if (!source || !exactKeys(source, ['schema_version', 'media_session_id', 'publication_generation', 'platform', 'client_kind', 'capability_version', 'sequence', 'capture', 'encode', 'transport'], ['sender_sample_age_ms'])) return null
  if (JSON.stringify(source).length > maxEnvelopeBytes) return null
  if (source.schema_version !== 1 || typeof source.media_session_id !== 'string' || !sessionPattern.test(source.media_session_id) ||
      !integerInRange(source.publication_generation, 1, maxSafeSequence) || !integerInRange(source.capability_version, 1, 16) ||
      !integerInRange(source.sequence, 1, maxSafeSequence) || (source.sender_sample_age_ms !== undefined && !integerInRange(source.sender_sample_age_ms, 0, 60_000))) return null
  const platform = source.platform
  const clientKind = source.client_kind
  if (!['web', 'android', 'ios', 'macos', 'windows'].includes(platform as string) || !['web', 'flutter'].includes(clientKind as string) ||
      (platform === 'web' ? clientKind !== 'web' : clientKind !== 'flutter')) return null
  const capture = record(source.capture)
  const encode = record(source.encode)
  const transport = record(source.transport)
  if (!capture || !exactKeys(capture, ['width', 'height', 'fps']) || !encode || !exactKeys(encode, ['fps', 'bitrate_bps']) ||
      !transport || !exactKeys(transport, ['packet_loss_percent', 'rtt_ms', 'quality_limitation_reason'])) return null
  const width = numericMetric(capture.width, 1, 16_384, true)
  const height = numericMetric(capture.height, 1, 16_384, true)
  const captureFps = numericMetric(capture.fps, 0, 240)
  const encodeFps = numericMetric(encode.fps, 0, 240)
  const bitrate = numericMetric(encode.bitrate_bps, 0, 100_000_000, true)
  const packetLoss = numericMetric(transport.packet_loss_percent, 0, 100)
  const rtt = numericMetric(transport.rtt_ms, 0, 60_000)
  const qualityReason = categoricalMetric(transport.quality_limitation_reason)
  if (!width || !height || !captureFps || !encodeFps || !bitrate || !packetLoss || !rtt || !qualityReason) return null
  return {
    schema_version: 1,
    media_session_id: source.media_session_id,
    publication_generation: source.publication_generation,
    platform: platform as ScreenTelemetryEnvelopeV1['platform'],
    client_kind: clientKind as ScreenTelemetryEnvelopeV1['client_kind'],
    capability_version: source.capability_version,
    sequence: source.sequence,
    ...(source.sender_sample_age_ms === undefined ? {} : { sender_sample_age_ms: source.sender_sample_age_ms as number }),
    capture: { width, height, fps: captureFps },
    encode: { fps: encodeFps, bitrate_bps: bitrate },
    transport: { packet_loss_percent: packetLoss, rtt_ms: rtt, quality_limitation_reason: qualityReason },
  }
}

export function parseScreenTelemetryEvent(value: unknown): ScreenTelemetryEventV1 {
  const source = record(value)
  if (!source || !exactKeys(source, ['owner_lease_id', 'server_received_at', 'envelope']) ||
      typeof source.owner_lease_id !== 'string' || !uuidPattern.test(source.owner_lease_id) ||
      typeof source.server_received_at !== 'string' || !dateTimePattern.test(source.server_received_at) || Number.isNaN(Date.parse(source.server_received_at))) {
    throw new Error('Некорректное realtime-событие телеметрии экрана.')
  }
  const envelope = parseEnvelope(source.envelope)
  if (!envelope) throw new Error('Некорректное realtime-событие телеметрии экрана.')
  return { ownerLeaseId: source.owner_lease_id.toLowerCase(), serverReceivedAt: source.server_received_at, envelope }
}

function sameSelection(left: ScreenTelemetryPublicationSelection | null, right: ScreenTelemetryPublicationSelection | null): boolean {
  return left?.streamId === right?.streamId && left?.ownerLeaseId.toLowerCase() === right?.ownerLeaseId.toLowerCase() &&
    left?.mediaSessionId === right?.mediaSessionId && left?.publicationGeneration === right?.publicationGeneration
}

export class SelectedScreenTelemetry {
  private selection: ScreenTelemetryPublicationSelection | null = null
  private latest: ReceivedScreenTelemetry | undefined
  private readonly highWater = new Map<string, { sequence: number; receivedAtMs: number }>()

  setSelection(selection: ScreenTelemetryPublicationSelection | null): void {
    if (sameSelection(this.selection, selection)) return
    this.selection = selection ? { ...selection, ownerLeaseId: selection.ownerLeaseId.toLowerCase() } : null
    this.latest = undefined
  }

  accept(value: unknown, nowMonotonicMs = performance.now()): boolean {
    const selection = this.selection
    if (!selection) return false
    let event: ScreenTelemetryEventV1
    try { event = parseScreenTelemetryEvent(value) } catch { return false }
    const receivedAtMs = Date.parse(event.serverReceivedAt)
    const scopeKey = `${event.ownerLeaseId}/${event.envelope.media_session_id}/${event.envelope.publication_generation}`
    const previous = this.highWater.get(scopeKey)
    if (!Number.isFinite(nowMonotonicMs) || (event.envelope.sender_sample_age_ms ?? 0) > screenTelemetryFreshnessMs ||
        event.ownerLeaseId !== selection.ownerLeaseId || event.envelope.media_session_id !== selection.mediaSessionId ||
        event.envelope.publication_generation !== selection.publicationGeneration ||
        (previous && (event.envelope.sequence <= previous.sequence || receivedAtMs <= previous.receivedAtMs))) return false
    this.latest = { ...event, serverReceivedAtMs: receivedAtMs, receivedAtMonotonicMs: nowMonotonicMs }
    this.highWater.delete(scopeKey)
    this.highWater.set(scopeKey, { sequence: event.envelope.sequence, receivedAtMs })
    if (this.highWater.size > 32) this.highWater.delete(this.highWater.keys().next().value!)
    return true
  }

  current(nowMonotonicMs = performance.now()): ReceivedScreenTelemetry | undefined {
    if (!this.latest) return undefined
    const ageMs = nowMonotonicMs - this.latest.receivedAtMonotonicMs
    return ageMs >= 0 && ageMs <= screenTelemetryFreshnessMs ? this.latest : undefined
  }

  clear(): void {
    this.selection = null
    this.latest = undefined
  }
}
