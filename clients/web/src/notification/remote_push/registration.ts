const key = 'boohtacord-notification-instances-v1'
// Opaque profile metadata only; no endpoint, provider keys or credentials.
export function notificationInstance(scope: string): string {
  let previous: unknown = []
  try { previous = JSON.parse(localStorage.getItem(key) ?? '[]') } catch { /* malformed local metadata is discarded */ }
  const now = Date.now()
  const rows = (Array.isArray(previous) ? previous : []).filter(v => v && typeof v.scope === 'string' && typeof v.instance === 'string' && /^[0-9a-f-]{36}$/.test(v.instance) && Number.isFinite(v.expires) && v.expires > now).slice(-31)
  const known = rows.find(v => v.scope === scope)
  if (known) return known.instance
  const instance = crypto.randomUUID()
  rows.push({ scope, instance, expires: now + 90 * 86400000 })
  localStorage.setItem(key, JSON.stringify(rows))
  return instance
}
