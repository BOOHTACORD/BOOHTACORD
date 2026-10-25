import { validNotificationRealtime } from '../notification/remote_push/realtime'
import { apiBaseUrl } from '../config/runtime'
import { isVoiceLeaseRevocationReason } from '../voice/voice_lease_revocation_reason'
import { parseScreenPreviewHint } from '../voice/screen_preview/client'

export type RealtimeKind = 'notification.queued' | 'notification.preferences_changed' | 'connection.ready' | 'connection.resync_required' | 'voice.lease_revoked' | 'channel.updated' | 'presence.snapshot' | 'presence.changed' | 'message.created' | 'message.updated' | 'message.deleted' | 'direct_message.message_created' | 'direct_message.message_updated' | 'direct_message.message_deleted' | 'role.permissions.updated' | 'auth.permissions.invalidated' | 'session.state_changed' | 'guild.profile.updated' | 'member.profile.updated' | 'screen_preview.updated' | 'screen_preview.invalidated' | 'screen_viewers.changed' | 'message.reactions_updated' | 'message.pins_updated' | 'direct_message.reactions_updated'
export interface RealtimeEvent {
  eventId: string
  kind: RealtimeKind
  occurredAt: string
  payload: Record<string, unknown>
  telemetry?: {reference:string;traceId:string;spanId:string}
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}
function uuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
}
function keys(payload: Record<string, unknown>, expected: string[]): boolean {
  return Object.keys(payload).length === expected.length && expected.every((key) => Object.hasOwn(payload, key))
}
function revision(value: unknown): boolean { return typeof value === 'number' && Number.isInteger(value) && value >= 1 }

export function parseRealtimeEvent(value: unknown): RealtimeEvent {
  const source = record(value)
  const kind = source?.kind
  const payload = record(source?.payload)
  if (!source || typeof source.event_id !== 'string' || typeof source.occurred_at !== 'string' || Number.isNaN(Date.parse(source.occurred_at)) || typeof kind !== 'string' || !['notification.queued', 'notification.preferences_changed', 'connection.ready', 'connection.resync_required', 'voice.lease_revoked', 'channel.updated', 'presence.snapshot', 'presence.changed', 'message.created', 'message.updated', 'message.deleted', 'direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted', 'role.permissions.updated', 'auth.permissions.invalidated', 'session.state_changed', 'guild.profile.updated', 'member.profile.updated', 'screen_preview.updated', 'screen_preview.invalidated', 'screen_viewers.changed', 'message.reactions_updated', 'message.pins_updated', 'direct_message.reactions_updated'].includes(kind) || !payload) {
    throw new Error('Сервер вернул некорректное realtime-событие.')
  }
  if (!validNotificationRealtime(kind,payload)) throw new Error('Некорректное событие уведомлений.')
  if (kind === 'presence.snapshot' && (Object.keys(payload).length !== 1 || !Array.isArray(payload.online_user_ids) || !payload.online_user_ids.every(uuid))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'presence.changed' && (Object.keys(payload).length !== 2 || !uuid(payload.user_id) || (payload.presence !== 'online' && payload.presence !== 'offline'))) throw new Error('Некорректное realtime-событие.')
  if (['message.created', 'message.updated', 'message.deleted', 'message.reactions_updated', 'message.pins_updated'].includes(kind) && (!keys(payload, ['channel_id', 'message_id']) || !uuid(payload.channel_id) || !uuid(payload.message_id))) throw new Error('Некорректное realtime-событие.')
  if ((kind === 'direct_message.message_created' || kind === 'direct_message.reactions_updated') && (!keys(payload, ['direct_message_id', 'message_id']) || !uuid(payload.direct_message_id) || !uuid(payload.message_id))) throw new Error('Некорректное realtime-событие.')
  if ((kind === 'direct_message.message_updated' || kind === 'direct_message.message_deleted') && (!keys(payload, ['direct_message_id', 'message_id', 'revision']) || !uuid(payload.direct_message_id) || !uuid(payload.message_id) || !revision(payload.revision))) throw new Error('Некорректное realtime-событие.')
  if ((kind === 'channel.updated' || kind === 'guild.profile.updated') && (!keys(payload, ['revision']) || !revision(payload.revision))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'member.profile.updated' && (!keys(payload, ['user_id', 'revision']) || !uuid(payload.user_id) || !revision(payload.revision))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'screen_viewers.changed' && Object.keys(payload).length !== 0) throw new Error('Некорректное realtime-событие.')
  if (kind === 'voice.lease_revoked' && (!keys(payload, ['lease_id', 'reason']) || !uuid(payload.lease_id) || !isVoiceLeaseRevocationReason(payload.reason))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'screen_preview.updated' && (!keys(payload, ['lease_id', 'generation_id', 'revision']) || !parseScreenPreviewHint(payload))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'screen_preview.invalidated' && (!keys(payload, ['lease_id', 'generation_id']) || !uuid(payload.lease_id) || !uuid(payload.generation_id))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'role.permissions.updated' && (!keys(payload, ['role', 'revision']) || payload.role !== 'MEMBER' || !revision(payload.revision))) throw new Error('Некорректное realtime-событие.')
  if ((kind === 'auth.permissions.invalidated' || kind === 'session.state_changed') && Object.keys(payload).length !== 0) throw new Error('Некорректное realtime-событие.')
  const metadata=record(source.telemetry)
  const telemetry=metadata&&typeof metadata.reference==='string'&&metadata.reference.length<=512&&
    typeof metadata.trace_id==='string'&&/^[0-9a-f]{32}$/.test(metadata.trace_id)&&typeof metadata.span_id==='string'&&/^[0-9a-f]{16}$/.test(metadata.span_id)
    ? {reference:metadata.reference,traceId:metadata.trace_id,spanId:metadata.span_id}:undefined
  return { eventId: source.event_id, kind: kind as RealtimeKind, occurredAt: source.occurred_at, payload, ...(telemetry?{telemetry}:{}) }
}

export interface RealtimeLocation { protocol: string; host: string }

export function realtimeURL(location: RealtimeLocation = window.location, after?: string): string {
  const base = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}${apiBaseUrl}/realtime?capabilities=role_permissions_v1,flow_tracing_v1,screen_previews_v1,screen_viewers_v1,message_social_v1,notifications_v1`
  return after ? `${base}&after=${encodeURIComponent(after)}` : base
}

export function realtimeTraceURL(target: string, traceparent?: string, tracestate?: string,fields:Record<string,string>={}): string {
  if(typeof window!=='undefined'&&new URL(target).host!==window.location.host)return target
  if (!traceparent) return target
  const parentURL = `${target}${target.includes('?') ? '&' : '?'}traceparent=${encodeURIComponent(traceparent)}`
  const stateURL=tracestate ? `${parentURL}&tracestate=${encodeURIComponent(tracestate)}` : parentURL
  const allowed=['telemetry_session','visit','flow','flow_name','attempt']
  return stateURL+Object.entries(fields).filter(([key])=>allowed.includes(key)).map(([key,value])=>`&${key}=${encodeURIComponent(value)}`).join('')
}
