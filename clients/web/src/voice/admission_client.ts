import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'

export interface VoiceLease {
  id: string
  channelId: string
  transferred: boolean
}

export interface LiveKitCredential {
  url: string
  token: string
  expiresAt: string
  microphoneAllowed?: boolean
}

export type VoiceRequest = (input: string, init: RequestInit) => Promise<Response>

export class VoiceRequestError extends Error {
  constructor(readonly status: number, readonly code?: string, readonly activeChannelId?: string) {
    super(code ? `Голосовой запрос отклонён: ${code}.` : `Голосовой запрос отклонён (${status}).`)
  }
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null
}

function string(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

async function json(response: Response): Promise<unknown> {
  try {
    return await response.json()
  } catch {
    return null
  }
}

async function checked(response: Response): Promise<unknown> {
  const body = await json(response)
  if (response.ok) return body

  const detail = record(body)
  const error = detail?.error
  throw new VoiceRequestError(
    response.status,
    string(record(error)?.code) ?? undefined,
    string(detail?.active_channel_id) ?? undefined,
  )
}

function lease(value: unknown): VoiceLease {
  const body = record(value)
  if (!body || typeof body.transferred !== 'boolean') throw new Error('Сервер вернул некорректный voice lease.')

  const id = string(body.id)
  const channelId = string(body.channel_id)
  if (!id || !channelId) throw new Error('Сервер вернул некорректный voice lease.')

  return { id, channelId, transferred: body.transferred }
}

function credential(value: unknown): LiveKitCredential {
  const body = record(value)
  const url = string(body?.url)
  const token = string(body?.token)
  const expiresAt = string(body?.expires_at)
  const microphoneAllowed = body?.microphone_allowed === undefined ? true : body.microphone_allowed
  if (!url || !token || !expiresAt || typeof microphoneAllowed !== 'boolean') throw new Error('Сервер вернул некорректный media credential.')

  return { url, token, expiresAt, microphoneAllowed }
}

function mutation(method: string, body?: unknown): RequestInit {
  return {
    method,
    credentials: 'same-origin',
    headers: { accept: 'application/json', ...(body ? { 'content-type': 'application/json' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  }
}

export async function acquireVoiceLease(
  channelId: string,
  transfer: boolean,
  request: VoiceRequest = tracedFetch,
): Promise<VoiceLease> {
  const response = await request(`${apiBaseUrl}/voice/channels/${encodeURIComponent(channelId)}/leases`, mutation('POST', { transfer }))
  return lease(await checked(response))
}

export async function issueLiveKitCredential(leaseId: string, request: VoiceRequest = tracedFetch): Promise<LiveKitCredential> {
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(leaseId)}/credential`, mutation('POST'))
  return credential(await checked(response))
}

export async function releaseVoiceLease(leaseId: string, request: VoiceRequest = tracedFetch): Promise<void> {
  const response = await request(`${apiBaseUrl}/voice/leases/${encodeURIComponent(leaseId)}`, mutation('DELETE'))
  await checked(response)
}
