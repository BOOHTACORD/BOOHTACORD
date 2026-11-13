import { timestamp } from './roster_payload'

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const kinds = new Set(['maintenance.snapshot', 'maintenance.changed', 'voice.roster.snapshot', 'voice.roster.unavailable'])
const object = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value)
const exact = (value: Record<string, unknown>, keys: string[]) => Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key))

export class NewRealtimeEnvelopeError extends Error {}

export function validateNewRealtimeEnvelope(source: Record<string, unknown>): void {
  if (typeof source.kind !== 'string' || !kinds.has(source.kind)) return
  const keys = ['event_id', 'kind', 'occurred_at', 'payload']
  if (Object.hasOwn(source, 'telemetry')) keys.push('telemetry')
  if (!exact(source, keys) || typeof source.event_id !== 'string' || !uuid.test(source.event_id) || !timestamp(source.occurred_at) || !object(source.payload)) throw new NewRealtimeEnvelopeError('Некорректное realtime-событие.')
  if (!Object.hasOwn(source, 'telemetry')) return
  const t = source.telemetry
  if (!object(t) || !exact(t, ['reference', 'trace_id', 'span_id']) || typeof t.reference !== 'string' || !t.reference.length || t.reference.length > 512 || typeof t.trace_id !== 'string' || !/^(?!0{32}$)[0-9a-f]{32}$/.test(t.trace_id) || typeof t.span_id !== 'string' || !/^(?!0{16}$)[0-9a-f]{16}$/.test(t.span_id)) throw new NewRealtimeEnvelopeError('Некорректное realtime-событие.')
}
