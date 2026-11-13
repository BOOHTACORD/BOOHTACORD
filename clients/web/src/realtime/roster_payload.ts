const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const time = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$/i
const record = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value)
const keys = (value: Record<string, unknown>, names: string[]) => Object.keys(value).length === names.length && names.every(name => Object.hasOwn(value, name))
const id = (value: unknown): value is string => typeof value === 'string' && uuid.test(value)

export function timestamp(value: unknown): boolean {
  if (typeof value !== 'string') return false
  const match = time.exec(value)
  if (!match || Number.isNaN(Date.parse(value))) return false
  const [, y, m, d, h, min, sec, zone] = match
  const calendar = new Date(0); calendar.setUTCFullYear(Number(y), Number(m) - 1, Number(d)); calendar.setUTCHours(0, 0, 0, 0)
  if (calendar.getUTCFullYear() !== Number(y) || calendar.getUTCMonth() !== Number(m) - 1 || calendar.getUTCDate() !== Number(d)) return false
  if (Number(h) > 23 || Number(min) > 59 || Number(sec) > 59) return false
  return zone.toUpperCase() === 'Z' || (Number(zone.slice(1, 3)) <= 23 && Number(zone.slice(4, 6)) <= 59)
}

function participants(value: unknown): boolean {
  if (!Array.isArray(value)) return false
  const seen = new Set<string>()
  return value.every(item => {
    if (!record(item) || !keys(item, ['account_id', 'display_name', 'screen_sharing', 'microphone_muted']) || !id(item.account_id) || seen.has(item.account_id.toLowerCase())) return false
    seen.add(item.account_id.toLowerCase())
    return typeof item.display_name === 'string' && [...item.display_name].length >= 1 && [...item.display_name].length <= 64 && typeof item.screen_sharing === 'boolean' && typeof item.microphone_muted === 'boolean'
  })
}

export function validVoiceRosterRealtime(kind: string, payload: Record<string, unknown>): boolean {
  if (kind === 'voice.roster.unavailable') return keys(payload, ['version', 'code']) && payload.version === 1 && payload.code === 'temporarily_unavailable'
  if (kind !== 'voice.roster.snapshot') return true
  if (!keys(payload, ['version', 'generation', 'revision', 'observed_at', 'channels']) || payload.version !== 1 || !id(payload.generation) || !Number.isSafeInteger(payload.revision) || Number(payload.revision) < 1 || !timestamp(payload.observed_at) || !Array.isArray(payload.channels)) return false
  const seen = new Set<string>()
  return payload.channels.every(channel => {
    if (!record(channel) || !keys(channel, ['channel_id', 'participants']) || !id(channel.channel_id) || seen.has(channel.channel_id.toLowerCase())) return false
    seen.add(channel.channel_id.toLowerCase())
    return participants(channel.participants)
  })
}
