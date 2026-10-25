export function notificationUTC(value: unknown): number {
  if (typeof value !== 'string') return NaN
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(Z|[+]00:00)$/.exec(value)
  const time = new Date(value)
  if (!match || !Number.isFinite(time.getTime()) || time.getUTCFullYear() < 1) return NaN
  const parts = [time.getUTCFullYear(), time.getUTCMonth() + 1, time.getUTCDate(), time.getUTCHours(), time.getUTCMinutes(), time.getUTCSeconds()]
  return parts.every((part, i) => part === Number(match[i + 1])) ? time.getTime() : NaN
}
