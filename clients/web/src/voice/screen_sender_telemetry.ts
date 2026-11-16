import { apiBaseUrl } from '../config/runtime'
import type { ScreenDiagnostics } from './screen_diagnostics'

export type ScreenTelemetryAvailability =
  | 'measured'
  | 'configured_only'
  | 'unsupported'
  | 'not_exposed'
  | 'permission_denied'
  | 'not_applicable'
  | 'stale'

export interface ScreenTelemetryMetric {
  value?: number
  availability: ScreenTelemetryAvailability
  provenance: 'sender_measured' | 'configured' | 'unavailable'
}

export interface ScreenTelemetryCategoricalMetric {
  value?: string
  availability: ScreenTelemetryAvailability
  provenance: 'sender_measured' | 'configured' | 'unavailable'
}

export interface ScreenTelemetryPublicationScope {
  ownerLeaseId: string
  mediaSessionId: string
  publicationGeneration: number
  captureWidth?: number
  captureHeight?: number
  captureFps?: number
}

export interface ScreenTelemetryEnvelopeV1 {
  schema_version: 1
  media_session_id: string
  publication_generation: number
  platform: 'web'
  client_kind: 'web'
  capability_version: 1
  sequence: number
  sender_sample_age_ms?: number
  capture: { width: ScreenTelemetryMetric; height: ScreenTelemetryMetric; fps: ScreenTelemetryMetric }
  encode: { fps: ScreenTelemetryMetric; bitrate_bps: ScreenTelemetryMetric }
  transport: {
    packet_loss_percent: ScreenTelemetryMetric
    rtt_ms: ScreenTelemetryMetric
    quality_limitation_reason: ScreenTelemetryCategoricalMetric
  }
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const mediaSession = /^[A-Za-z0-9_-]{1,256}$/
const maximumAgeMs = 15_000
const maximumEnvelopeBytes = 2_048

function unavailable(availability: Exclude<ScreenTelemetryAvailability, 'measured' | 'configured_only'>): ScreenTelemetryMetric {
  return { availability, provenance: 'unavailable' }
}

function measured(value: number | undefined, maximum: number, integral = false, availability: ScreenTelemetryAvailability = 'measured'): ScreenTelemetryMetric {
  if (availability === 'stale') return unavailable('stale')
  if (value === undefined || !Number.isFinite(value) || value < 0 || value > maximum || (integral && !Number.isInteger(value))) {
    return unavailable('not_exposed')
  }
  return { value, availability: 'measured', provenance: 'sender_measured' }
}

function configured(value: number | undefined, maximum: number, integral = false): ScreenTelemetryMetric {
  if (value === undefined || !Number.isFinite(value) || value < 0 || value > maximum || (integral && !Number.isInteger(value))) {
    return unavailable('not_exposed')
  }
  return { value, availability: 'configured_only', provenance: 'configured' }
}

function dynamicMetric(
  value: number | undefined,
  maximum: number,
  unsupported: boolean,
  stale: boolean,
  integral = false,
): ScreenTelemetryMetric {
  if (stale) return unavailable('stale')
  if (unsupported) return unavailable('unsupported')
  const metricValue = integral && value !== undefined && Number.isFinite(value) && value >= 0 && value <= maximum
    ? Math.round(value)
    : value
  return measured(metricValue, maximum, integral)
}

function dynamicReason(value: string | undefined, unsupported: boolean, stale: boolean): ScreenTelemetryCategoricalMetric {
  if (stale) return { availability: 'stale', provenance: 'unavailable' }
  if (unsupported) return { availability: 'unsupported', provenance: 'unavailable' }
  if (!value || !['none', 'bandwidth', 'cpu', 'encoder'].includes(value)) {
    return { availability: 'not_exposed', provenance: 'unavailable' }
  }
  return { value, availability: 'measured', provenance: 'sender_measured' }
}

function sampleAge(nowMs: number, sampledAt: number | undefined): number | undefined {
  if (sampledAt === undefined) return undefined
  const age = nowMs - sampledAt
  return Number.isFinite(age) && age >= 0 ? Math.floor(age) : undefined
}

export function buildWebScreenTelemetryEnvelope(input: {
  scope: ScreenTelemetryPublicationScope
  diagnostics: ScreenDiagnostics
  sequence: number
  nowMs: number
}): ScreenTelemetryEnvelopeV1 | null {
  const { scope, diagnostics, sequence, nowMs } = input
  if (!uuid.test(scope.ownerLeaseId) || !mediaSession.test(scope.mediaSessionId) ||
    !Number.isSafeInteger(scope.publicationGeneration) || scope.publicationGeneration < 1 ||
    !Number.isSafeInteger(sequence) || sequence < 1 || !Number.isFinite(nowMs)) return null

  const age = sampleAge(nowMs, diagnostics.sampledAt)
  const stale = diagnostics.sampledAt !== undefined && (age === undefined || age > maximumAgeMs)
  const unsupported = diagnostics.senderStatsAvailable === false
  const reason = diagnostics.selectedLayer?.qualityLimitationReason ?? diagnostics.adaptationReason
  const lossWindow = diagnostics.packetLossWindowMs
  const loss = lossWindow != null && lossWindow >= 9_000 ? diagnostics.packetLossPercent ?? undefined : undefined
  const envelope: ScreenTelemetryEnvelopeV1 = {
    schema_version: 1,
    media_session_id: scope.mediaSessionId,
    publication_generation: scope.publicationGeneration,
    platform: 'web',
    client_kind: 'web',
    capability_version: 1,
    sequence,
    ...(age !== undefined && age <= 60_000 ? { sender_sample_age_ms: age } : {}),
    capture: {
      width: measured(scope.captureWidth, 16_384, true),
      height: measured(scope.captureHeight, 16_384, true),
      fps: configured(scope.captureFps, 240),
    },
    encode: {
      fps: dynamicMetric(diagnostics.selectedLayer?.framesPerSecond ?? diagnostics.measured?.framesPerSecond, 240, unsupported, stale),
      bitrate_bps: dynamicMetric(diagnostics.selectedLayer?.bitrateBps ?? diagnostics.bitrateBps, 100_000_000, unsupported, stale, true),
    },
    transport: {
      packet_loss_percent: dynamicMetric(loss, 100, unsupported, stale),
      rtt_ms: dynamicMetric(diagnostics.selectedLayer?.roundTripTimeMs ?? diagnostics.roundTripTimeMs, 60_000, unsupported, stale),
      quality_limitation_reason: dynamicReason(reason, unsupported, stale),
    },
  }
  if (new TextEncoder().encode(JSON.stringify(envelope)).byteLength > maximumEnvelopeBytes) return null
  return envelope
}

export type ScreenTelemetryRequest = (input: string, init: RequestInit) => Promise<Response>

export async function postScreenTelemetryEnvelope(
  ownerLeaseId: string,
  envelope: ScreenTelemetryEnvelopeV1,
  request: ScreenTelemetryRequest = fetch,
): Promise<void> {
  if (!uuid.test(ownerLeaseId)) throw new Error('Не удалось отправить диагностику трансляции экрана.')
  const body = JSON.stringify(envelope)
  if (new TextEncoder().encode(body).byteLength > maximumEnvelopeBytes) throw new Error('Не удалось отправить диагностику трансляции экрана.')
  const controller = new AbortController()
  const timeout = globalThis.setTimeout(() => controller.abort(), 10_000)
  try {
    const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(ownerLeaseId)}/screen-telemetry`, {
      method: 'POST', mode: 'same-origin', redirect: 'error', referrerPolicy: 'no-referrer', credentials: 'same-origin', cache: 'no-store',
      headers: { accept: 'application/json', 'content-type': 'application/json' }, body, signal: controller.signal,
    })
    if (!response.ok) throw new Error('Не удалось отправить диагностику трансляции экрана.')
  } finally {
    globalThis.clearTimeout(timeout)
  }
}
