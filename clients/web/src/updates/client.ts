import type { UpdatePolicy, UpdateTarget } from './types'

export class UpdateCheckError extends Error {
  constructor(message: string, readonly retryAfterMs?: number) { super(message) }
}

const path = '/api/v1/client-updates?platform=web&distribution=browser&channel=stable&arch=any'
const record = (value: unknown): value is Record<string, unknown> => Boolean(value) && typeof value === 'object' && !Array.isArray(value)
function safeURL(raw: string | null): boolean {
  if (raw === null) return true
  if (raw.length > 2048 || raw.startsWith('//')) return false
  if (raw.startsWith('/')) return true
  const url = new URL(raw, typeof location === 'undefined' ? 'https://invalid.local' : location.origin)
  return url.protocol === 'https:' && !url.username && !url.password
}

function parseTarget(value: unknown): UpdateTarget {
  if (!record(value)) throw new Error('Invalid client update target')
  const requirements = value.requirements
  const action = value.action
  if (!record(requirements) || !Array.isArray(requirements.supported_arches) || !requirements.supported_arches.every((item) => typeof item === 'string')) throw new Error('Invalid update requirements')
  if (!record(action) || !['reload','open_download_page','open_store','open_instructions'].includes(String(action.kind)) || (action.url !== null && typeof action.url !== 'string')) throw new Error('Invalid update action')
  if (typeof value.release_id !== 'string' || typeof value.release_order !== 'number' || typeof value.version !== 'string' || (value.native_build !== null && typeof value.native_build !== 'string') || !['normal','important'].includes(String(value.priority)) || typeof value.summary !== 'string' || (value.release_notes_url !== null && typeof value.release_notes_url !== 'string')) throw new Error('Invalid release identity')
  if (value.minimum_release_order != null && (!Number.isInteger(value.minimum_release_order) || (value.minimum_release_order as number) < 1 || (value.minimum_release_order as number) > 2147483647 || (value.minimum_release_order as number) > (value.release_order as number))) throw new Error('Invalid minimum release order')
  if (!safeURL(action.url as string | null) || !safeURL(value.release_notes_url as string | null)) throw new Error('Unsafe update URL')
  return value as unknown as UpdateTarget
}

export function parsePolicy(value: unknown): UpdatePolicy {
  if (!record(value)) throw new Error('Invalid client update policy')
  if (value.application_family !== 'boohtacord' || value.platform !== 'web' || value.distribution !== 'browser' || value.channel !== 'stable' || value.arch !== 'any') throw new Error('Client update selector mismatch')
  if (!Number.isInteger(value.catalog_revision) || !['published','unconfigured','disabled'].includes(String(value.state))) throw new Error('Invalid client update policy')
  const target = value.target === null ? null : parseTarget(value.target)
  if ((value.state === 'published') !== Boolean(target)) throw new Error('Invalid client update policy state')
  return value as unknown as UpdatePolicy
}

export async function fetchUpdatePolicy(request: typeof fetch = fetch): Promise<UpdatePolicy> {
  const controller = new AbortController()
  const timer = globalThis.setTimeout(() => controller.abort(), 5_000)
  try {
    const response = await request(path, { method:'GET', credentials:'omit', cache:'no-store', headers:{ Accept:'application/json' }, signal:controller.signal })
    if (!response.ok) {
      const seconds = Number(response.headers.get('retry-after'))
      const retryAfterMs = response.status === 404 ? 30*60_000 : response.status === 429 && Number.isFinite(seconds) ? seconds*1_000 : undefined
      throw new UpdateCheckError(`Update check failed (${response.status})`, retryAfterMs)
    }
    if (!response.headers.get('content-type')?.includes('application/json')) throw new UpdateCheckError('Update check returned another content type')
    return parsePolicy(await response.json())
  } finally { globalThis.clearTimeout(timer) }
}
