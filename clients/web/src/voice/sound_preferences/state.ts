import { ref } from 'vue'
import { apiBaseUrl } from '../../config/runtime'
import { SafetyFence, browserStorage, type Storage } from './safety'

export type SoundSettings = { enabled: boolean; joined: boolean; left: boolean; started: boolean; stopped: boolean; allow_custom: boolean; volume: number }
type SoundSnapshot = { revision: number; settings: SoundSettings }
type Request = (input: string, init: RequestInit) => Promise<Response>
const keys = ['enabled', 'joined', 'left', 'started', 'stopped', 'allow_custom'] as const
const muted = (): SoundSettings => ({ enabled: false, joined: false, left: false, started: false, stopped: false, allow_custom: false, volume: 0 })

function parse(value: unknown): SoundSnapshot {
  if (!value || typeof value !== 'object') throw new Error('Invalid voice preferences')
  const source = value as Record<string, unknown>, settings = source.settings
  if (!Number.isSafeInteger(source.revision) || (source.revision as number) < 0 || !settings || typeof settings !== 'object') throw new Error('Invalid voice preferences')
  const body = settings as Record<string, unknown>
  if (keys.some(key => typeof body[key] !== 'boolean') || !Number.isInteger(body.volume) || (body.volume as number) < 0 || (body.volume as number) > 100) throw new Error('Invalid voice preferences')
  return { revision: source.revision as number, settings: Object.fromEntries([...keys.map(key => [key, body[key]]), ['volume', body.volume]]) as SoundSettings }
}

export class VoiceSoundPreferences {
  readonly settings = ref<SoundSettings>(muted())
  readonly unsynchronised = ref(false)
  private account: string | null = null
  private revision: number | null = null
  private generation = 0
  private edits = 0
  private saving = false
  private readonly safety: SafetyFence
  constructor(private readonly request: Request = fetch, storage: Storage | null = browserStorage()) { this.safety = new SafetyFence(storage) }
  async select(account: string | null): Promise<void> {
    if (account !== null && account === this.account && this.revision !== null && this.unsynchronised.value) return
    const generation = ++this.generation
    this.account = account; this.revision = null; this.settings.value = muted(); this.unsynchronised.value = false; this.saving = false; this.edits = 0
    if (!account) return
    try {
      const result = await this.request(`${apiBaseUrl}/me/voice-sound-preferences`, { credentials: 'same-origin', headers: { 'X-Voice-Sound-Account': account } })
      if (!result.ok) throw new Error('Preference load failed')
      const data = parse(await result.json())
      if (generation !== this.generation) return
      this.revision = data.revision; this.settings.value = this.safety.apply(data.settings, account); this.unsynchronised.value = this.safety.has(account)
    } catch { if (generation === this.generation) this.unsynchronised.value = true }
  }
  async patch(change: Partial<SoundSettings>): Promise<void> {
    const account = this.account, generation = this.generation
    if (!account || this.revision === null) { this.unsynchronised.value = true; return }
    const edit = ++this.edits
    this.safety.remember(account, change, this.settings.value)
    this.settings.value = this.safety.apply(this.settings.value, account)
    this.unsynchronised.value = true
    if (this.saving) { this.unsynchronised.value = true; return }
    this.saving = true
    try {
      const result = await this.request(`${apiBaseUrl}/me/voice-sound-preferences`, { method: 'PATCH', credentials: 'same-origin', headers: { 'X-Voice-Sound-Account': account, 'content-type': 'application/json' }, body: JSON.stringify({ expected_revision: this.revision, ...change }) })
      if (!result.ok) throw new Error('Preference save failed')
      const data = parse(await result.json())
      if (generation !== this.generation) return
      if (data.revision <= this.revision || Object.entries(change).some(([key, value]) => data.settings[key as keyof SoundSettings] !== value)) throw new Error('Preference save was not acknowledged')
      this.revision = data.revision
      if (edit === this.edits) { this.safety.acknowledge(account, change); this.settings.value = this.safety.apply(data.settings, account); this.unsynchronised.value = this.safety.has(account) }
      else this.unsynchronised.value = true
    } catch { if (generation === this.generation) this.unsynchronised.value = true }
    finally { if (generation === this.generation) this.saving = false }
  }
}
