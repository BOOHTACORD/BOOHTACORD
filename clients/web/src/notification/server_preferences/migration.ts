import type { Override } from './client'

export interface MigrationPreview { overrides: Override[]; local_disabled: boolean; source_present: boolean; errors: string[] }
const uuid = /^(?!00000000-0000-0000-0000-000000000000$)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
export function previewLegacyPreferences(storage: Pick<Storage, 'getItem'> | null, account: string): MigrationPreview {
  const result: MigrationPreview = { overrides: [], local_disabled: false, source_present: false, errors: [] }
  if (!storage) return result
  try {
    const prefix = `boohtacord:notification:${account}`
    const enabled = storage.getItem(`${prefix}:enabled`)
    const raw = storage.getItem(`${prefix}:conversations:v1`)
    result.local_disabled = enabled === '0'
    result.source_present = raw !== null || enabled !== null
    if (raw === null) return result
    if (raw.length > 32768) throw new Error('Legacy preferences exceed the import limit')
    const data: unknown = JSON.parse(raw)
    if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error('Invalid legacy preferences')
    const entries = Object.entries(data)
    if (entries.length > 100) throw new Error('Too many explicit preferences')
    for (const [key, candidate] of entries) {
      const split = key.indexOf(':'); const kind = key.slice(0, split); const id = key.slice(split + 1)
      if (!['CHANNEL', 'DIRECT_MESSAGE'].includes(kind) || !uuid.test(id) || !candidate || typeof candidate !== 'object') throw new Error('Invalid conversation preference')
      const value = candidate as Record<string, unknown>
      if (!['all', 'mentions', 'none'].includes(String(value.mode)) || !Number.isSafeInteger(value.pausedUntil) || Number(value.pausedUntil) < 0) throw new Error('Invalid conversation preference')
      const paused = Number(value.pausedUntil)
      result.overrides.push({ kind: kind as Override['kind'], id, mode: value.mode as Override['mode'], paused_until: paused === 0 ? null : new Date(paused).toISOString() })
    }
  } catch { result.overrides = []; result.errors.push('Локальные настройки повреждены; импорт недоступен.') }
  return result
}
