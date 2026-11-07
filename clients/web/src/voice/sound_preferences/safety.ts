import type { SoundSettings } from './state'
export type Storage = Pick<globalThis.Storage, 'getItem' | 'setItem' | 'removeItem'>
const booleans = ['enabled', 'joined', 'left', 'started', 'stopped', 'allow_custom'] as const
type Safety = Partial<SoundSettings>
function key(account: string): string { return `voice-sound-pending-off:v2:${account}` }
export function browserStorage(): Storage | null { try { return typeof localStorage === 'undefined' ? null : localStorage } catch { return null } }
export class SafetyFence {
  private memory = new Map<string, Safety>()
  constructor(private readonly storage: Storage | null) {}
  read(account: string): Safety {
    if (this.memory.has(account)) return { ...this.memory.get(account) }
    let raw: unknown
    try { raw = JSON.parse(this.storage?.getItem(key(account)) ?? '{}') } catch { raw = {} }
    const source = raw && typeof raw === 'object' ? raw as Record<string, unknown> : {}
    const safe: Safety = {}
    for (const field of booleans) if (source[field] === false) safe[field] = false
    if (Number.isInteger(source.volume) && (source.volume as number) >= 0 && (source.volume as number) <= 100) safe.volume = source.volume as number
    this.memory.set(account, safe); return { ...safe }
  }
  remember(account: string, change: Partial<SoundSettings>, current: SoundSettings): void {
    const safety = this.read(account)
    for (const field of booleans) if (change[field] === false) safety[field] = false
    if (typeof change.volume === 'number' && Number.isInteger(change.volume) && change.volume >= 0 && change.volume < current.volume) safety.volume = Math.min(safety.volume ?? 100, change.volume)
    this.write(account, safety)
  }
  acknowledge(account: string, change: Partial<SoundSettings>): void {
    const safety = this.read(account)
    for (const field of [...booleans, 'volume'] as const) if (field in change) delete safety[field]
    this.write(account, safety)
  }
  apply(settings: SoundSettings, account: string): SoundSettings {
    const safety = this.read(account), result = { ...settings }
    for (const field of booleans) if (safety[field] === false) result[field] = false
    if (safety.volume !== undefined) result.volume = Math.min(result.volume, safety.volume)
    return result
  }
  has(account: string): boolean { return Object.keys(this.read(account)).length > 0 }
  private write(account: string, value: Safety): void {
    this.memory.set(account, value)
    try { if (Object.keys(value).length) this.storage?.setItem(key(account), JSON.stringify(value)); else this.storage?.removeItem(key(account)) } catch { /* Keep the in-memory safety fence. */ }
  }
}
