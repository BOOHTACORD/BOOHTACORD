import type { ScreenDescriptorOwner, ScreenShareDescriptorV1 } from './types'

export const SCREEN_DESCRIPTOR_ATTRIBUTE = 'boohtacord.screen-share.v1'
export const SCREEN_DESCRIPTOR_MAX_BYTES = 4096
const profiles = new Set(['P720_15', 'P720_30', 'P720_60', 'P1080_15', 'P1080_30', 'P1080_60', 'P1440_15', 'P1440_30', 'P1440_60'])
const publishers = new Set(['idle', 'requesting', 'capturing', 'publishing', 'sharing', 'updating', 'stopping', 'failed'])
const viewers = new Set(['idle', 'subscribing', 'waiting-first-frame', 'playing', 'suspended', 'recovering', 'ended', 'failed'])
const reasons = new Set(['user-request', 'platform-constraint', 'network-adaptation', 'no-subscribers', 'sdk-paused', 'unsupported-profile', 'capture-denied', 'publish-failed', 'superseded', 'session-revoked', 'logout', 'unknown'])

type Data = Record<string, unknown>
const record = (value: unknown): value is Data => typeof value === 'object' && value !== null && !Array.isArray(value)
const exact = (value: Data, names: string[]) => Object.keys(value).length === names.length && names.every(name => Object.hasOwn(value, name))
const text = (value: unknown, limit = 256) => typeof value === 'string' && value.length > 0 && value.length <= limit
const whole = (value: unknown, minimum = 0) => Number.isSafeInteger(value) && Number(value) >= minimum

export function parseScreenDescriptor(raw: string | undefined, owner: ScreenDescriptorOwner): ScreenShareDescriptorV1 | undefined {
  if (!raw || new TextEncoder().encode(raw).byteLength > SCREEN_DESCRIPTOR_MAX_BYTES) return undefined
  let value: unknown
  try { value = JSON.parse(raw) } catch { return undefined }
  if (!record(value) || !valid(value) || !scopeMatches(value.scope as Data, owner)) return undefined
  return value as unknown as ScreenShareDescriptorV1
}

export function isNewerScreenDescriptor(candidate: ScreenShareDescriptorV1, current: ScreenShareDescriptorV1): boolean {
  const left = candidate.scope, right = current.scope
  return left.origin_id === right.origin_id && left.account_id === right.account_id && left.room_id === right.room_id
    && left.operation_revision > right.operation_revision
}

function valid(value: Data): boolean {
  if (!exact(value, ['schema_version', 'scope', 'mode', 'publisher_state', 'viewer_state', 'requested_profile_id', 'effective_profile', 'layer_topology', 'profile_revision', 'capabilities', 'reason_codes']) || value.schema_version !== 1) return false
  const profile = String(value.requested_profile_id)
  if (!profiles.has(profile) || !validScope(value.scope) || !validEffective(value.effective_profile)) return false
  if (value.mode !== 'motion' && value.mode !== 'text') return false
  if (!publishers.has(String(value.publisher_state)) || !viewers.has(String(value.viewer_state))) return false
  if (!['single-layer', 'bounded-simulcast'].includes(String(value.layer_topology)) || !whole(value.profile_revision)) return false
  if (!validCapabilities(value.capabilities) || !Array.isArray(value.reason_codes) || value.reason_codes.length > 8) return false
  return new Set(value.reason_codes).size === value.reason_codes.length && value.reason_codes.every(reason => reasons.has(String(reason)))
}

function validScope(value: unknown): boolean {
  return record(value) && exact(value, ['origin_id', 'account_id', 'room_id', 'media_session_id', 'publication_generation', 'operation_revision'])
    && text(value.origin_id) && text(value.account_id) && text(value.room_id) && text(value.media_session_id)
    && whole(value.publication_generation) && whole(value.operation_revision)
}

function validEffective(value: unknown): boolean {
  if (!record(value) || !exact(value, ['capture', 'encoding']) || !record(value.capture) || !record(value.encoding)) return false
  if (!exact(value.capture, ['max_width', 'max_height', 'max_fps']) || !whole(value.capture.max_width, 2) || !whole(value.capture.max_height, 2) || !whole(value.capture.max_fps, 1)) return false
  if (!exact(value.encoding, ['codec', 'layers']) || !(value.encoding.codec === null || text(value.encoding.codec, 32))) return false
  const layers = value.encoding.layers
  return Array.isArray(layers) && layers.length > 0 && layers.length <= 2 && layers.every(validLayer)
}

function validLayer(value: unknown): boolean {
  return record(value) && exact(value, ['rid', 'width', 'height', 'max_fps', 'max_bitrate_bps', 'scale_down_by', 'active'])
    && (value.rid === null || text(value.rid, 32)) && whole(value.width, 2) && whole(value.height, 2)
    && whole(value.max_fps, 1) && whole(value.max_bitrate_bps, 1) && typeof value.scale_down_by === 'number'
    && Number.isFinite(value.scale_down_by) && value.scale_down_by >= 1 && typeof value.active === 'boolean'
}

function validCapabilities(value: unknown): boolean {
  return record(value) && exact(value, ['live_update', 'republish_without_recapture', 'simulcast'])
    && typeof value.live_update === 'boolean' && typeof value.republish_without_recapture === 'boolean' && typeof value.simulcast === 'boolean'
}

function scopeMatches(scope: Data, owner: ScreenDescriptorOwner): boolean {
  return scope.origin_id === owner.originId && scope.account_id === owner.accountId && scope.room_id === owner.roomId
}
